import express from 'express';
import { createProxyMiddleware } from 'http-proxy-middleware';
import dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import { dirname } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

dotenv.config();

const app = express();
const port = process.env.DEEPSEEK_PROXY_PORT || 9000;

// Log incoming requests
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.url}`);
  next();
});

// Proxy middleware configuration
const proxyOptions = {
  target: 'https://api.deepseek.com',
  changeOrigin: true,
  onProxyReq: (proxyReq, req, res) => {
    // Add the API key to the request
    const apiKey = process.env.DEEPSEEK_API_KEY;
    if (!apiKey) {
      console.error('DEEPSEEK_API_KEY is not set in environment variables');
      return;
    }
    proxyReq.setHeader('Authorization', `Bearer ${apiKey}`);
    
    console.log(`[${new Date().toISOString()}] Proxying request to: ${req.method} ${req.url}`);
  },
  onError: (err, req, res) => {
    console.error(`[${new Date().toISOString()}] Proxy error:`, err);
    res.status(500).json({ error: 'Proxy error occurred' });
  }
};

// Create proxy middleware
const proxy = createProxyMiddleware(proxyOptions);

// Apply proxy to all routes
app.use('/', proxy);

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

app.listen(port, () => {
  console.log(`DeepSeek proxy server running on port ${port}`);
}); 