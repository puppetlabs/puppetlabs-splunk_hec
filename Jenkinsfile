// Update this once Bill's helpers are merged into the shared library repo
@Library('puppet_jenkins_shared_libraries') _

pipeline{
    agent {
        label 'worker'
    }
    environment {
      RUBY_VERSION='2.5.7'
      GEM_SOURCE='https://artifactory.delivery.puppetlabs.net/artifactory/api/gems/rubygems/'
      RAKE_SETUP_TASK='rake acceptance:setup'
      RAKE_TEST_TASK='rake acceptance:run_tests'
      RAKE_TEARDOWN_TASK='rake acceptance:tear_down'
      CI='true'
      RESULTS_FILE_NAME='rspec_junit_results.xml'
    }
    stages{

        stage('Setup') {
            steps {
                echo 'Bundle Install'
                bundleInstall env.RUBY_VERSION
                bundleExec env.RUBY_VERSION, env.RAKE_SETUP_TASK
            }
        }

        stage('Run Tests') {
            steps {
                echo 'Run Tests'
                bundleExec env.RUBY_VERSION, env.RAKE_TEST_TASK
            }
        }
    }
    post{
        always {
            script {
                if(fileExists(env.RESULTS_FILE_NAME)) {
                    junit testResults: env.RESULTS_FILE_NAME, allowEmptyResults: true
                }
            }
        }
        cleanup {
            bundleExec env.RUBY_VERSION, env.RAKE_TEARDOWN_TASK
        }
    }
}
