pipeline {
  agent any

  options {
    disableConcurrentBuilds()
    buildDiscarder(logRotator(numToKeepStr: '10'))
    timestamps()
    timeout(time: 20, unit: 'MINUTES')
  }

  parameters {
    string(
      name: 'BRANCH_NAME',
      defaultValue: 'main',
      trim: true,
      description: '要构建部署的 Git 分支（任务分支合并入 main 后直接填 main）'
    )
    booleanParam(
      name: 'DEPLOY_BACKEND',
      defaultValue: true,
      description: '是否编译测试并部署后端 Spring Boot 服务'
    )
    booleanParam(
      name: 'DEPLOY_ADMIN',
      defaultValue: true,
      description: '是否构建并部署管理后台 (frontend-admin)'
    )
    booleanParam(
      name: 'DEPLOY_DOWNLOAD',
      defaultValue: true,
      description: '是否更新部署 App 下载官网 (frontend-download)'
    )
    booleanParam(
      name: 'SKIP_TESTS',
      defaultValue: false,
      description: '是否跳过后端单元测试（紧急发版时可勾选）'
    )
  }

  environment {
    MAVEN_OPTS = '-Xms128m -Xmx384m -XX:+UseG1GC'
    MAVEN_USER_HOME = '/opt/jenkins/m2'
    PNPM_STORE_DIR = '/opt/jenkins/pnpm-store'
    DEPLOY_BIN = '/usr/local/bin/guoguanla-deploy'
  }

  stages {
    stage('检出代码') {
      steps {
        script {
          def targetBranch = (params.BRANCH_NAME ?: 'main').trim()
          retry(2) {
            checkout([
              $class: 'GitSCM',
              branches: [[name: "*/${targetBranch}"]],
              extensions: [[$class: 'CloneOption', shallow: true, depth: 1]],
              userRemoteConfigs: scm.userRemoteConfigs
            ])
          }
          sh """
            echo "当前构建分支: ${targetBranch}"
            git log -1 --oneline
          """
        }
      }
    }

    stage('构建后端 (Java)') {
      when {
        expression { return params.DEPLOY_BACKEND }
      }
      steps {
        dir('backend') {
          sh '''
            set -e
            chmod +x ./mvnw
            mkdir -p "${MAVEN_USER_HOME}"
            if [ "${SKIP_TESTS}" = "true" ]; then
              ./mvnw -B -DskipTests -Dmaven.compiler.fork=false clean package
            else
              ./mvnw -B -Dmaven.compiler.fork=false clean package
            fi
          '''
        }
      }
    }

    stage('构建管理后台 (Web)') {
      when {
        expression { return params.DEPLOY_ADMIN }
      }
      steps {
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

    stage('部署后端服务') {
      when {
        expression { return params.DEPLOY_BACKEND }
      }
      steps {
        sh '''
          set -e
          sudo ${DEPLOY_BIN} backend "${WORKSPACE}/backend/target/guoguanla-backend-1.0.0.jar"
        '''
      }
    }

    stage('部署管理后台') {
      when {
        expression { return params.DEPLOY_ADMIN }
      }
      steps {
        sh '''
          set -e
          sudo ${DEPLOY_BIN} admin "${WORKSPACE}/frontend-admin/dist"
        '''
      }
    }

    stage('部署 App 下载官网') {
      when {
        expression { return params.DEPLOY_DOWNLOAD }
      }
      steps {
        sh '''
          set -e
          sudo ${DEPLOY_BIN} download "${WORKSPACE}/frontend-download"
        '''
      }
    }

    stage('线上健康检查') {
      steps {
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
