#!/usr/bin/env groovy

pipeline{
    agent any

    environment {
        BVERSION = '1.0.0'
    }

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    stages{
        stage("Build"){
            steps{
                echo "========Copying backup/packages========"
                sh """
                if [ -f /dev_OS_build/backup-temp-tools-${env.BVERSION}.tar.xz ]; then
                    cp -v /dev_OS_build/backup-temp-tools-${env.BVERSION}.tar.xz backup/
                else
                    cp -v /dev_OS_build/source/* bin/
                fi
                """

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
