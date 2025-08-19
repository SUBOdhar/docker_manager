### Docker Manager: A Complete Solution for Docker Management

**A cross-platform mobile application and API for seamless control of your Docker environment.**

-----

### 1\. Project Overview

Docker Manager is a comprehensive solution designed to simplify the management of Docker containers, images, and networks directly from your mobile device. This project is ideal for developers, system administrators, and anyone who needs a quick and convenient way to monitor and control their Docker environment without being tied to a desktop terminal.

The solution is split into two main components:

  * **Docker Manager API:** A robust and lightweight backend service built with Node.js and Express.js. It acts as an intermediary, securely interacting with the Docker daemon on your host machine to perform management tasks.
  * **Docker Manager App:** A cross-platform mobile application developed using Flutter. It provides an intuitive and responsive user interface for real-time monitoring and control of your Docker setup.

-----

### 2\. Core Technologies

| Component           | Language / Framework                                       | Key Features                                                              |
| ------------------- | ---------------------------------------------------------- | ------------------------------------------------------------------------- |
| **Backend (API)** | **JavaScript** |                                                                           |
|                     | **Node.js** | High-performance, event-driven runtime environment.                       |
|                     | **Express.js** | Fast, unopinionated web framework for building REST APIs.                 |
|                     | **Docker** & **Docker Compose** | Containerization and orchestration for easy deployment.                   |
| **Frontend (App)** | **Dart** | A modern, object-oriented language optimized for client-side development. |
|                     | **Flutter** | Google's UI toolkit for building natively compiled, beautiful applications. |
| **Version Control** | **Git** | Distributed version control system for tracking changes.                  |

-----

### 3\. Getting Started: How to Build and Run for Yourself

This guide will walk you through the process of setting up and running the Docker Manager application and its API.

#### 3.1. Prerequisites

Before you begin, ensure you have the following software installed on your system.

  * **Git:** [Installation Guide](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
  * **Docker & Docker Compose:** [Installation Guide](https://docs.docker.com/get-docker/)
  * **Flutter SDK:** [Installation Guide](https://flutter.dev/docs/get-started/install)

#### 3.2. Step 1: Clone the Repository

Open your terminal or command prompt and clone the project repository from GitHub.

```bash
git clone https://github.com/SUBOdhar/docker_manager.git
```

This command will create a new directory named `docker_manager` containing all the project files.

#### 3.3. Step 2: Set Up and Run the API (Backend)

The backend is containerized using Docker Compose, which simplifies the deployment process.

1.  Navigate into the API directory:

    ```bash
    cd docker_manager/docker_manager_api
    ```

2.  Run the Docker Compose command to build and start the API service. The `-d` flag detaches the process, allowing it to run in the background.

    ```bash
    docker-compose up -d
    ```

      * **What this does:** Docker Compose reads the `docker-compose.yml` file, builds the necessary Docker image for the Node.js application (if it doesn't exist), and starts the container. The API will be accessible on port 3000 by default.
      * **Troubleshooting:** If you encounter issues, ensure the Docker daemon is running and that your user has the necessary permissions to interact with the Docker socket.

3.  **Verify the API is running:** Check the status of the running containers with:

    ```bash
    docker ps
    ```

    You should see a container for `docker_manager_api` listed.

#### 3.4. Step 3: Build and Install the Mobile Application (Frontend)

Now, you will build the Flutter mobile app that connects to the API you just started.

1.  Navigate back to the main project directory and then into the app directory:

    ```bash
    cd ../docker_manager_app
    ```

2.  **For a Quick Test (Development Build):** To run the app on a connected device with hot reload, first ensure your device is recognized by Flutter by running `flutter devices`. Then, execute:

    ```bash
    flutter run
    ```

3.  **For a Production-Ready Release Build:** Build the Android APK. The `--release` flag optimizes the app for production use, resulting in a smaller file size and better performance.

    ```bash
    flutter build apk --release
    ```

      * **Note:** This command downloads all required Flutter dependencies and compiles the Dart code into a release-ready Android application package (`.apk`). This process may take a few minutes depending on your system's performance.

4.  **Install the APK on your Device:**

      * **Option A: Manual Installation:** Locate the generated `.apk` file at:

        ```
        build/app/outputs/flutter-apk/app-release.apk
        ```

        Transfer this file to your Android device and install it. You may need to enable "Install from Unknown Sources" in your device's security settings.

      * **Option B: Command Line Installation:** If you have USB Debugging enabled on your mobile device and it's connected to your computer, you can install the app directly:

        ```bash
        flutter install --release
        ```

#### 3.5. Step 4: Connect the App to the API

For the app to communicate with the backend, both your mobile device and the computer running the API must be on the same network.

1.  Ensure your mobile device and the computer running the Docker API are connected to the same Wi-Fi network.
2.  When you launch the app for the first time, you will be prompted to enter the IP address of the computer hosting the API.
3.  You can find your local IP address using a command like `ipconfig` (Windows) or `ifconfig` / `ip addr` (Linux/macOS) in your terminal. Enter this IP address in the app's settings.

-----

### 4\. Contribution

Your contributions are highly valued\! If you find bugs, have feature requests, or want to contribute to the codebase, please follow these steps:

1.  Fork the repository on GitHub.
2.  Create your feature branch: `git checkout -b my-new-feature`.
3.  Commit your changes: `git commit -am 'Add some feature'`.
4.  Push to the branch: `git push origin my-new-feature`.
5.  Create a new Pull Request with a clear description of your changes.

-----

### 5\. License

This project is licensed under the MIT License - see the `LICENSE` file for details.