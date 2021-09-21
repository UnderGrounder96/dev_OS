#!/usr/bin/env groovy

pipeline{
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    stages{
        stage("Build"){
            steps{
                echo "========Copying packages========"
                sh 'cp -v /source/* bin/'

                echo "========Executing Build========"
                sh 'bash vagrant_start.sh'

                // stash includes: '*.iso', name: 'dev_OS_iso'
            }
        }

        // stage("Test"){
        //     steps{
        //         unstash 'dev_OS_iso'

        //         echo "========Executing Test========"
        //         sh 'bash vagrant_test.sh'
        //     }
        // }
    }

    post{
        always{
            archiveArtifacts artifacts: 'logs/*.log*'
        }
    }
}
