pipeline {
    agent any

    tools {
        maven 'Maven-3.9.16'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build & Test') {
            steps {
                sh 'mvn clean test package'
            }
        }
    }
}