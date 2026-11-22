// 由 Jenkins guoguanla-deploy 在拉取仓库分支后通过 `load 'Jenkinsfile'` 执行
def doBackend = (params.DEPLOY_BACKEND == null) ? true : params.DEPLOY_BACKEND.toString().toBoolean()
def doAdmin = (params.DEPLOY_ADMIN == null) ? true : params.DEPLOY_ADMIN.toString().toBoolean()
def doDownload = (params.DEPLOY_DOWNLOAD == null) ? true : params.DEPLOY_DOWNLOAD.toString().toBoolean()
def skipTests = (params.SKIP_TESTS != null) && params.SKIP_TESTS.toString().toBoolean()

timeout(time: 20, unit: 'MINUTES') {
  timestamps {
    withEnv([
      'MAVEN_OPTS=-Xms128m -Xmx384m -XX:+UseG1GC',
      'MAVEN_USER_HOME=/opt/jenkins/m2',
      'PNPM_STORE_DIR=/opt/jenkins/pnpm-store',
      'DEPLOY_BIN=/usr/local/bin/guoguanla-deploy',
      'HUSKY=0'
    ]) {
      if (doBackend) {
        stage('构建后端 (Java)') {
          dir('backend') {
            sh """
              set -e
              chmod +x ./mvnw
              mkdir -p "\${MAVEN_USER_HOME}"
              if [ "${skipTests}" = "true" ]; then
                ./mvnw -B -DskipTests -Dmaven.compiler.fork=false clean package
              else
                ./mvnw -B -Dmaven.compiler.fork=false clean package
              fi
            """
          }
        }
      }

      if (doAdmin) {
        stage('构建管理后台 (Web)') {
          dir('frontend-admin') {
            sh '''
              set -e
              mkdir -p "${PNPM_STORE_DIR}"
              pnpm install --frozen-lockfile --store-dir "${PNPM_STORE_DIR}" --registry=https://registry.npmmirror.com
              NODE_OPTIONS=--max-old-space-size=1024 pnpm typecheck
              rm -rf dist
              NODE_OPTIONS=--max-old-space-size=1024 pnpm exec vite build
            '''
          }
        }
      }

      if (doBackend) {
        stage('部署后端服务') {
          sh '''
            set -e
            sudo ${DEPLOY_BIN} backend "${WORKSPACE}/backend/target/guoguanla-backend-1.0.0.jar"
          '''
        }
      }

      if (doAdmin) {
        stage('部署管理后台') {
          sh '''
            set -e
            sudo ${DEPLOY_BIN} admin "${WORKSPACE}/frontend-admin/dist"
          '''
        }
      }

      if (doDownload) {
        stage('部署 App 下载官网') {
          sh '''
            set -e
            sudo ${DEPLOY_BIN} download "${WORKSPACE}/frontend-download"
          '''
        }
      }

      stage('线上健康检查') {
        sh '''
          set -e
          curl -sf http://127.0.0.1:8080/api/app/home/summary >/dev/null
          curl -sfI http://127.0.0.1/ | head -n 5
          curl -sfI http://127.0.0.1/download/ | head -n 5
          echo "全部服务健康检查通过"
        '''
      }
    }
  }
}
