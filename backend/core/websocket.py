import json
import asyncio
from typing import Dict, List, Set
from fastapi import WebSocket, WebSocketDisconnect
from .logger import system_logger

class ConnectionManager:
    def __init__(self):
        # dictionary of user_id -> set of active WebSockets
        self.active_connections: Dict[str, Set[WebSocket]] = {}

    async def connect(self, user_id: str, websocket: WebSocket):
        await websocket.accept()
        if user_id not in self.active_connections:
            self.active_connections[user_id] = set()
        self.active_connections[user_id].add(websocket)
        system_logger.info(f"User {user_id} connected. Total connections for user: {len(self.active_connections[user_id])}")

    def disconnect(self, user_id: str, websocket: WebSocket):
        if user_id in self.active_connections:
            self.active_connections[user_id].remove(websocket)
            if not self.active_connections[user_id]:
                del self.active_connections[user_id]
        system_logger.info(f"User {user_id} disconnected.")

    async def send_personal_message(self, message: dict, user_id: str):
        if user_id in self.active_connections:
            dead_connections = set()
            for connection in self.active_connections[user_id]:
                try:
                    await connection.send_text(json.dumps(message))
                except Exception as e:
                    system_logger.error(f"Error sending message to user {user_id}: {e}")
                    dead_connections.add(connection)
            
            # Clean up dead connections
            for dead in dead_connections:
                self.active_connections[user_id].remove(dead)

    async def broadcast(self, message: dict):
        for user_id in list(self.active_connections.keys()):
            await self.send_personal_message(message, user_id)

manager = ConnectionManager()

async def broadcast_event(event_type: str, payload: dict, user_id: str = None):
    """
    Standardized event broadcasting.
    If user_id is provided, sends to that specific user.
    Otherwise, broadcasts to all connected users.
    """
    message = {
        "event": event_type,
        "timestamp": asyncio.get_event_loop().time(),
        "payload": payload
    }
    
    if user_id:
        await manager.send_personal_message(message, user_id)
    else:
        await manager.broadcast(message)
