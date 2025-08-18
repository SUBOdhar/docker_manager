const express = require("express");
const Docker = require("dockerode");

const app = express();
const port = 1113;

// The key to this entire setup: Connect to the Docker daemon socket
const docker = new Docker({ socketPath: "/var/run/docker.sock" });

app.use(express.json());

// Helper function to handle async/await in Express routes
const asyncMiddleware = (fn) => (req, res, next) => {
  Promise.resolve(fn(req, res, next)).catch(next);
};

// =========================================================
// API ENDPOINTS
// =========================================================

// GET /containers - List all containers
app.get(
  "/containers",
  asyncMiddleware(async (req, res) => {
    const containers = await docker.listContainers({ all: true });
    res.json(
      containers.map((c) => ({
        id: c.Id,
        name: c.Names.join(", "),
        image: c.Image,
        status: c.Status,
        state: c.State,
      }))
    );
  })
);

// POST /containers - Create a new container
app.post(
  "/containers",
  asyncMiddleware(async (req, res) => {
    const { Image, name } = req.body;
    if (!Image || !name) {
      return res.status(400).json({ error: "Image and name are required." });
    }

    const container = await docker.createContainer({
      Image,
      name,
      Tty: false,
    });

    res
      .status(201)
      .json({ id: container.id, message: `Container '${name}' created.` });
  })
);

// GET /containers/:id - Get details of a single container
app.get(
  "/containers/:id",
  asyncMiddleware(async (req, res) => {
    const containerId = req.params.id;
    try {
      const container = docker.getContainer(containerId);
      const containerInfo = await container.inspect();
      res.json(containerInfo);
    } catch (error) {
      res.status(404).json({ error: "Container not found." });
    }
  })
);

// POST /containers/:id/start - Start a container
app.post(
  "/containers/:id/start",
  asyncMiddleware(async (req, res) => {
    const container = docker.getContainer(req.params.id);
    try {
      await container.start();
      res.json({ message: "Container started successfully." });
    } catch (error) {
      res
        .status(404)
        .json({ error: "Container not found or is already running." });
    }
  })
);

// POST /containers/:id/stop - Stop a container
app.post(
  "/containers/:id/stop",
  asyncMiddleware(async (req, res) => {
    const container = docker.getContainer(req.params.id);
    try {
      await container.stop();
      res.json({ message: "Container stopped successfully." });
    } catch (error) {
      res
        .status(404)
        .json({ error: "Container not found or is already stopped." });
    }
  })
);

// POST /containers/:id/restart - Restart a container
app.post(
  "/containers/:id/restart",
  asyncMiddleware(async (req, res) => {
    const container = docker.getContainer(req.params.id);
    try {
      await container.restart();
      res.json({ message: "Container restarted successfully." });
    } catch (error) {
      res.status(404).json({ error: "Container not found." });
    }
  })
);

// DELETE /containers/:id - Delete a container
app.delete(
  "/containers/:id",
  asyncMiddleware(async (req, res) => {
    const container = docker.getContainer(req.params.id);
    try {
      await container.remove();
      res.json({ message: "Container removed successfully." });
    } catch (error) {
      res
        .status(404)
        .json({ error: "Container not found or is still running." });
    }
  })
);

// Global error handler
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ error: "Something went wrong on the server." });
});

app.listen(port, () => {
  console.log(`Docker API server listening on http://localhost:${port}`);
});
