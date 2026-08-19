from __future__ import annotations

import json
import os
import queue
import time
import uuid
from multiprocessing import Process, Queue
from typing import Any
from urllib.parse import parse_qs

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse


WORKER_COUNT = max(1, min(10, int(os.getenv("AI_WORKER_COUNT", "1"))))
POLICY_MODE = os.getenv("AI_POLICY_MODE", "none")
REQUEST_TIMEOUT_SECONDS = float(os.getenv("AI_REQUEST_TIMEOUT_SECONDS", "0.08"))

app = FastAPI(title="Dota 2 Bot AI Backend")
request_queues: list[Queue] = []
response_queues: list[Queue] = []
workers: list[Process] = []
pending_responses: dict[int, dict[str, tuple[float, dict[str, Any]]]] = {}


def safe_int(value: Any, fallback: int = -1) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return fallback


def decide(snapshot: dict[str, Any], policy_mode: str) -> dict[str, Any]:
    bot_id = safe_int(snapshot.get("bot_id"))

    if policy_mode == "attack_nearest_enemy":
        enemies = snapshot.get("nearby_enemy_heroes") or []
        if enemies:
            return {
                "bot_id": bot_id,
                "action": "attack_unit",
                "target_player_id": safe_int(enemies[0].get("player_id")),
                "issued_at": time.time(),
                "debug": "attack_nearest_enemy",
            }

    if policy_mode == "move_forward":
        location = snapshot.get("location") or {}
        team = safe_int(snapshot.get("team"), 0)
        sign = 1 if team == 2 else -1
        return {
            "bot_id": bot_id,
            "action": "move_to_location",
            "location": {
                "x": float(location.get("x", 0)) + 350 * sign,
                "y": float(location.get("y", 0)) + 350 * sign,
                "z": float(location.get("z", 0)),
            },
            "issued_at": time.time(),
            "debug": "move_forward",
        }

    return {
        "bot_id": bot_id,
        "action": "none",
        "issued_at": time.time(),
        "debug": "fallback_to_lua",
    }


def worker_loop(worker_id: int, in_q: Queue, out_q: Queue, policy_mode: str) -> None:
    while True:
        item = in_q.get()
        if item is None:
            return

        request_id, snapshot = item
        try:
            response = decide(snapshot, policy_mode)
            response["worker_id"] = worker_id
            out_q.put((request_id, response))
        except Exception as exc:
            out_q.put(
                (
                    request_id,
                    {
                        "bot_id": snapshot.get("bot_id", -1),
                        "action": "none",
                        "issued_at": time.time(),
                        "error": str(exc),
                        "worker_id": worker_id,
                    },
                )
            )


@app.on_event("startup")
def startup() -> None:
    for worker_id in range(WORKER_COUNT):
        in_q: Queue = Queue()
        out_q: Queue = Queue()
        process = Process(
            target=worker_loop,
            args=(worker_id, in_q, out_q, POLICY_MODE),
            daemon=True,
        )
        process.start()
        request_queues.append(in_q)
        response_queues.append(out_q)
        pending_responses[worker_id] = {}
        workers.append(process)


@app.on_event("shutdown")
def shutdown() -> None:
    for in_q in request_queues:
        in_q.put(None)
    for process in workers:
        process.join(timeout=1.0)


@app.get("/health")
def health() -> dict[str, Any]:
    return {
        "ok": True,
        "worker_count": WORKER_COUNT,
        "policy_mode": POLICY_MODE,
    }


def pop_worker_response(worker_index: int, request_id: str) -> dict[str, Any] | None:
    now = time.monotonic()
    for cached_id, (cached_at, _) in list(pending_responses[worker_index].items()):
        if now - cached_at > 1.0:
            pending_responses[worker_index].pop(cached_id, None)

    cached = pending_responses[worker_index].pop(request_id, None)
    if cached is not None:
        return cached[1]

    try:
        response_id, response = response_queues[worker_index].get_nowait()
    except queue.Empty:
        return None

    if response_id == request_id:
        return response

    pending_responses[worker_index][response_id] = (time.monotonic(), response)
    return None


@app.post("/decide")
async def decide_route(request: Request) -> JSONResponse:
    body = (await request.body()).decode("utf-8")
    form = parse_qs(body)
    bot_id = safe_int((form.get("bot_id") or ["-1"])[0])
    snapshot_raw = (form.get("snapshot") or ["{}"])[0]

    try:
        snapshot = json.loads(snapshot_raw)
    except json.JSONDecodeError:
        snapshot = {"bot_id": bot_id}

    if bot_id < 0:
        bot_id = safe_int(snapshot.get("bot_id"))

    if not request_queues:
        return JSONResponse({"bot_id": bot_id, "action": "none", "error": "no_workers"})

    worker_index = bot_id % len(request_queues)
    request_id = str(uuid.uuid4())
    request_queues[worker_index].put((request_id, snapshot))

    deadline = time.monotonic() + REQUEST_TIMEOUT_SECONDS
    while time.monotonic() < deadline:
        response = pop_worker_response(worker_index, request_id)
        if response is not None:
            return JSONResponse(response)
        time.sleep(0.002)

    return JSONResponse(
        {
            "bot_id": bot_id,
            "action": "none",
            "issued_at": time.time(),
            "error": "worker_timeout",
            "worker_id": worker_index,
        }
    )


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("app:app", host="0.0.0.0", port=8765, reload=False)
