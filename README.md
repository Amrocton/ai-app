# ai-app

Учебное HTTP-приложение на Python. Сборка Docker-образа выполняется GitHub Actions при push в main и при отправке тега v*.

Контейнер слушает порт 8000. Сообщение ответа можно изменить переменной APP_MESSAGE.

## Jenkins CI

The `ai-app-ci` pipeline polls the `main` branch every two minutes. It tests the application, builds a `ci-<BUILD_NUMBER>` image, and publishes it to Docker Hub.

## Delivery

The same Docker image is used in development, staging, and production. The APP_ENV variable selects the environment, and GET /health returns OK for deployment checks.
