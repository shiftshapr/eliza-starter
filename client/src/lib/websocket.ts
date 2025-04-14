import { UUID } from "@elizaos/core";

const WS_BASE_URL = import.meta.env.VITE_WS_URL || `ws://${window.location.hostname}:${import.meta.env.VITE_SERVER_PORT || '3000'}/ws`;

class WebSocketClient {
    private ws: WebSocket | null = null;
    private reconnectAttempts = 0;
    private maxReconnectAttempts = 5;
    private reconnectTimeout = 1000; // Start with 1 second
    private messageHandlers: ((data: any) => void)[] = [];
    private connectionHandlers: ((connected: boolean) => void)[] = [];

    constructor(private agentId: UUID) {
        this.connect();
    }

    private connect() {
        if (this.ws?.readyState === WebSocket.OPEN) return;

        this.ws = new WebSocket(`${WS_BASE_URL}/${this.agentId}`);

        this.ws.onopen = () => {
            console.log('WebSocket connected');
            this.reconnectAttempts = 0;
            this.reconnectTimeout = 1000;
            this.connectionHandlers.forEach(handler => handler(true));
        };

        this.ws.onclose = () => {
            console.log('WebSocket disconnected');
            this.connectionHandlers.forEach(handler => handler(false));
            this.reconnect();
        };

        this.ws.onerror = (error) => {
            console.error('WebSocket error:', error);
            this.ws?.close();
        };

        this.ws.onmessage = (event) => {
            try {
                const data = JSON.parse(event.data);
                this.messageHandlers.forEach(handler => handler(data));
            } catch (error) {
                console.error('Error parsing WebSocket message:', error);
            }
        };
    }

    private reconnect() {
        if (this.reconnectAttempts >= this.maxReconnectAttempts) {
            console.error('Max reconnection attempts reached');
            return;
        }

        setTimeout(() => {
            console.log(`Attempting to reconnect (${this.reconnectAttempts + 1}/${this.maxReconnectAttempts})`);
            this.reconnectAttempts++;
            this.reconnectTimeout *= 2; // Exponential backoff
            this.connect();
        }, this.reconnectTimeout);
    }

    public send(message: string, file?: File) {
        if (this.ws?.readyState !== WebSocket.OPEN) {
            throw new Error('WebSocket is not connected');
        }

        const payload = {
            type: 'message',
            text: message,
            user: 'user',
            file: file ? {
                name: file.name,
                type: file.type,
                size: file.size
            } : undefined
        };

        this.ws.send(JSON.stringify(payload));
    }

    public onMessage(handler: (data: any) => void) {
        this.messageHandlers.push(handler);
        return () => {
            this.messageHandlers = this.messageHandlers.filter(h => h !== handler);
        };
    }

    public onConnectionChange(handler: (connected: boolean) => void) {
        this.connectionHandlers.push(handler);
        return () => {
            this.connectionHandlers = this.connectionHandlers.filter(h => h !== handler);
        };
    }

    public disconnect() {
        this.ws?.close();
        this.messageHandlers = [];
        this.connectionHandlers = [];
    }
}

export const createWebSocketClient = (agentId: UUID) => new WebSocketClient(agentId); 