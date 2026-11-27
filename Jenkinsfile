pipeline {
    agent any

    // Проверять удалённую ветку main каждые две минуты.
    triggers {
        pollSCM('*/2 * * * *')
    }

    stages {
        stage('Тесты') {
            steps {
                // Источник копируется в контейнер через docker cp: bind mount
                // workspace здесь был бы путём внутри Jenkins, которого нет на Docker-хосте.
                timestamps {
                    sh '''
                    set -eu
                    TEST_NAME="ai-app-test-${BUILD_NUMBER}"
                    cleanup() { docker rm -f "$TEST_NAME" >/dev/null 2>&1 || true; }
                    trap cleanup EXIT
                    docker create --name "$TEST_NAME" -w /workspace python:3.12-slim sleep infinity
                    docker cp "$WORKSPACE/app.py" "$TEST_NAME:/workspace/app.py"
                    docker cp "$WORKSPACE/test_app.py" "$TEST_NAME:/workspace/test_app.py"
                    docker cp "$WORKSPACE/requirements.txt" "$TEST_NAME:/workspace/requirements.txt"
                    docker start "$TEST_NAME" >/dev/null
                    docker exec "$TEST_NAME" python -m pip install --no-cache-dir -r requirements.txt
                    docker exec "$TEST_NAME" python -m pytest -q test_app.py
                '''
                }
            }
        }

        stage('Сборка образа') {
            steps {
                // Архив контекста отправляется через stdin, поэтому daemon не
                // пытается читать workspace Jenkins по bind mount с хоста.
                timestamps {
                    sh '''
                    set -eu
                    tar -C "$WORKSPACE" --exclude=.git --exclude=.github -cf - . \
                        | docker build -t "ai-app:ci-${BUILD_NUMBER}" -
                '''
                }
            }
        }

        stage('Публикация') {
            steps {
                // Токен Jenkins Credentials не записывается в Jenkinsfile.
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub',
                    usernameVariable: 'DH_USER',
                    passwordVariable: 'DH_TOKEN'
                )]) {
                    timestamps {
                        sh '''
                        set -eu
                        trap 'docker logout >/dev/null 2>&1 || true' EXIT
                        printf '%s' "$DH_TOKEN" | docker login --username "$DH_USER" --password-stdin
                        docker tag "ai-app:ci-${BUILD_NUMBER}" "$DH_USER/ai-app:ci-${BUILD_NUMBER}"
                        docker push "$DH_USER/ai-app:ci-${BUILD_NUMBER}"
                    '''
                        }
                }
            }
        }
    }
}
