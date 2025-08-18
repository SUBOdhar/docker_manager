/**
 * @fileoverview A Node.js and Express.js server for managing Docker containers,
 * images, networks, and volumes. This server exposes a RESTful API that the
 * Flutter Docker Manager app can connect to. It uses the 'dockerode' library
 * to interact with the Docker daemon.
 */

// Import necessary libraries
const express = require("express");
const cors = require("cors");
const Docker = require("dockerode");

// Initialize the Express application
const app = express();
const port = 1113; // The port the server will listen on

// Use middleware to enable Cross-Origin Resource Sharing (CORS) and parse JSON bodies
app.use(cors());
app.use(express.json());

// --- Docker Daemon Connection ---
// The path to the Docker daemon socket. This may vary depending on your OS.
// For Linux/macOS, it's typically '/var/run/docker.sock'.
// For Windows, you might need to connect via TCP:
// const docker = new Docker({ host: 'http://127.0.0.1', port: 2375 });
const docker = new Docker({ socketPath: "/var/run/docker.sock" });

/**
 * Utility function to handle API responses and errors.
 * @param {object} res The Express response object.
 * @param {number} statusCode The HTTP status code.
 * @param {string} message The message to send in the response.
 * @param {object} data Optional data to include in the response body.
 */
function sendResponse(res, statusCode, message, data = null) {
  res.status(statusCode).json({ message, data });
}

/**
 * Utility function to handle server-side errors.
 * @param {object} res The Express response object.
 * @param {Error} error The error object.
 * @param {string} defaultMessage The default error message to display.
 */
function handleServerError(res, error, defaultMessage) {
  console.error("API Error:", error);
  sendResponse(res, 500, `${defaultMessage}: ${error.message}`);
}

// --- API Endpoints for Containers ---

/**
 * GET /containers
 * Lists all Docker containers with their relevant details.
 * The response includes the container ID, name, image, status, and state.
 */
app.get("/containers", async (req, res) => {
  try {
    const containers = await docker.listContainers({ all: true });
    const containerList = containers.map((container) => ({
      id: container.Id,
      name: container.Names[0].replace("/", ""), // Clean up the name
      image: container.Image,
      status: container.Status,
      state: container.State,
      createdAt: container.Created,
    }));
    sendResponse(res, 200, "Containers fetched successfully", containerList);
  } catch (error) {
    handleServerError(res, error, "Failed to list containers");
  }
});

/**
 * POST /containers/:id/start
 * Starts a specific container by its ID.
 */
app.post("/containers/:id/start", async (req, res) => {
  try {
    const container = docker.getContainer(req.params.id);
    await container.start();
    sendResponse(res, 200, `Container ${req.params.id} started`);
  } catch (error) {
    handleServerError(res, error, "Failed to start container");
  }
});

/**
 * POST /containers/:id/stop
 * Stops a specific container by its ID.
 */
app.post("/containers/:id/stop", async (req, res) => {
  try {
    const container = docker.getContainer(req.params.id);
    await container.stop();
    sendResponse(res, 200, `Container ${req.params.id} stopped`);
  } catch (error) {
    handleServerError(res, error, "Failed to stop container");
  }
});

/**
 * POST /containers/:id/restart
 * Restarts a specific container by its ID.
 */
app.post("/containers/:id/restart", async (req, res) => {
  try {
    const container = docker.getContainer(req.params.id);
    await container.restart();
    sendResponse(res, 200, `Container ${req.params.id} restarted`);
  } catch (error) {
    handleServerError(res, error, "Failed to restart container");
  }
});

/**
 * DELETE /containers/:id
 * Deletes a specific container by its ID.
 * The container must not be running.
 */
app.delete("/containers/:id", async (req, res) => {
  try {
    const container = docker.getContainer(req.params.id);
    await container.remove();
    sendResponse(res, 200, `Container ${req.params.id} deleted`);
  } catch (error) {
    handleServerError(res, error, "Failed to delete container");
  }
});

/**
 * POST /containers
 * Creates a new container from a specified image, with optional network, volume, and port binds.
 * If the image is not found locally, it will be automatically pulled from Docker Hub.
 * Request body must contain 'Image' and 'name'.
 * Optional: 'networkName', 'volumeBinds' (array of 'volumeName:containerPath'), and 'portBindings' (array of 'hostPort:containerPort').
 */
app.post("/containers", async (req, res) => {
  const { Image, name, networkName, volumeBinds, portBindings } = req.body;
  if (!Image || !name) {
    return sendResponse(
      res,
      400,
      "Image and name are required in the request body."
    );
  }

  try {
    // Check if the image exists locally
    try {
      await docker.getImage(Image).inspect();
      console.log(`Image ${Image} found locally.`);
    } catch (e) {
      console.log(`Image ${Image} not found locally, attempting to pull...`);
      // If image not found, pull it from the registry
      const pullStream = await docker.pull(Image, {});
      await new Promise((resolve, reject) => {
        docker.modem.followProgress(pullStream, (err, res) => {
          if (err) return reject(err);
          resolve(res);
        });
      });
      console.log(`Image ${Image} pulled successfully.`);
    }

    const createOptions = {
      Image,
      name,
    };

    // Add network configuration if a network name is provided
    if (networkName) {
      createOptions.NetworkingConfig = {
        EndpointsConfig: {
          [networkName]: {},
        },
      };
    }

    // Initialize HostConfig if it doesn't exist
    createOptions.HostConfig = createOptions.HostConfig || {};

    // Add volume binds if provided
    if (volumeBinds && Array.isArray(volumeBinds)) {
      // The `volumeBinds` array should be in the format ["volumeName:containerPath", ...]
      createOptions.HostConfig.Binds = volumeBinds;
    }

    // Add port bindings if provided
    if (portBindings && Array.isArray(portBindings)) {
      const formattedPortBindings = {};
      portBindings.forEach((binding) => {
        // Example: "8080:80" or "8080:80/tcp"
        const [hostPort, containerPort] = binding.split(":");
        if (hostPort && containerPort) {
          formattedPortBindings[
            containerPort.includes("/") ? containerPort : `${containerPort}/tcp`
          ] = [{ HostPort: hostPort }];
        }
      });
      createOptions.HostConfig.PortBindings = formattedPortBindings;
    }

    // Now that the image is available, create the container with the specified options
    await docker.createContainer(createOptions);
    sendResponse(res, 201, `Container ${name} created successfully`);
  } catch (error) {
    handleServerError(res, error, "Failed to create container");
  }
});

/**
 * GET /containers/:id/logs
 * Streams logs from a container in real-time.
 * The 'follow' option keeps the stream open for new logs.
 */
app.get("/containers/:id/logs", async (req, res) => {
  const container = docker.getContainer(req.params.id);
  const options = {
    follow: true,
    stdout: true,
    stderr: true,
  };

  try {
    const logStream = await container.logs(options);
    logStream.on("data", (chunk) => {
      // Stream the log chunk to the client
      res.write(chunk.toString());
    });
    logStream.on("end", () => {
      res.end(); // End the response when the log stream ends
    });
    // Handle client disconnection
    req.on("close", () => {
      logStream.destroy();
    });
  } catch (error) {
    handleServerError(res, error, "Failed to get container logs");
  }
});

// --- API Endpoints for Images ---

/**
 * GET /images
 * Lists all Docker images.
 */
app.get("/images", async (req, res) => {
  try {
    const images = await docker.listImages();
    const imageList = images.map((image) => ({
      id: image.Id,
      name: image.RepoTags[0] || "<none>",
      size: `${(image.Size / (1024 * 1024)).toFixed(2)} MB`, // Convert size to MB
    }));
    sendResponse(res, 200, "Images fetched successfully", imageList);
  } catch (error) {
    handleServerError(res, error, "Failed to list images");
  }
});

/**
 * DELETE /images/:name
 * Deletes a specific image by its name.
 */
app.delete("/images/:name", async (req, res) => {
  try {
    const image = docker.getImage(req.params.name);
    await image.remove();
    sendResponse(res, 200, `Image ${req.params.name} deleted`);
  } catch (error) {
    handleServerError(res, error, "Failed to delete image");
  }
});

/**
 * POST /images/:name/pull
 * Pulls an image from Docker Hub.
 */
app.post("/images/:name/pull", async (req, res) => {
  try {
    const pullStream = await docker.pull(req.params.name, {});
    await new Promise((resolve, reject) => {
      docker.modem.followProgress(pullStream, (err, res) => {
        if (err) {
          return reject(err);
        }
        resolve(res);
      });
    });
    sendResponse(res, 200, `Image ${req.params.name} pulled successfully`);
  } catch (error) {
    handleServerError(res, error, "Failed to pull image");
  }
});

// --- API Endpoints for Networks ---

/**
 * GET /networks
 * Lists all Docker networks.
 */
app.get("/networks", async (req, res) => {
  try {
    const networks = await docker.listNetworks();
    const networkList = networks.map((network) => ({
      id: network.Id,
      name: network.Name,
    }));
    sendResponse(res, 200, "Networks fetched successfully", networkList);
  } catch (error) {
    handleServerError(res, error, "Failed to list networks");
  }
});

/**
 * POST /networks
 * Creates a new Docker network.
 * Request body must contain 'name'.
 */
app.post("/networks", async (req, res) => {
  const { name } = req.body;
  if (!name) {
    return sendResponse(res, 400, "Network name is required.");
  }
  try {
    const network = await docker.createNetwork({ name });
    sendResponse(res, 201, `Network ${network.name} created successfully`);
  } catch (error) {
    handleServerError(res, error, "Failed to create network");
  }
});

// --- API Endpoints for Volumes ---

/**
 * GET /volumes
 * Lists all Docker volumes.
 */
app.get("/volumes", async (req, res) => {
  try {
    const volumes = await docker.listVolumes();
    const volumeList = volumes.Volumes.map((volume) => ({
      name: volume.Name,
      mountpoint: volume.Mountpoint,
      size: volume.UsageData
        ? `${(volume.UsageData.Size / (1024 * 1024)).toFixed(2)} MB`
        : "N/A",
    }));
    sendResponse(res, 200, "Volumes fetched successfully", volumeList);
  } catch (error) {
    handleServerError(res, error, "Failed to list volumes");
  }
});

/**
 * POST /volumes
 * Creates a new Docker volume.
 * Request body must contain 'name'.
 */
app.post("/volumes", async (req, res) => {
  const { name } = req.body;
  if (!name) {
    return sendResponse(res, 400, "Volume name is required.");
  }
  try {
    const volume = await docker.createVolume({ name });
    sendResponse(res, 201, `Volume ${volume.name} created successfully`);
  } catch (error) {
    handleServerError(res, error, "Failed to create volume");
  }
});

/**
 * DELETE /volumes/:name
 * Deletes a specific Docker volume by its name.
 */
app.delete("/volumes/:name", async (req, res) => {
  try {
    const volume = docker.getVolume(req.params.name);
    await volume.remove();
    sendResponse(res, 200, `Volume ${req.params.name} deleted`);
  } catch (error) {
    handleServerError(res, error, "Failed to delete volume");
  }
});

// --- Start the Server ---
app.listen(port, () => {
  console.log(`Docker API server listening on http://localhost:${port}`);
});
