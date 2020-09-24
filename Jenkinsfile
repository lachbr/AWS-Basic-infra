pipeline 
{
  agent any
  stages 
  {
    //stage ('AWS-Basic-infra - Checkout') {
    //  steps
    //  {
    //    checkout([$class: 'GitSCM', branches: [[name: '*/master']], doGenerateSubmoduleConfigurations: false, extensions: [], submoduleCfg: [], userRemoteConfigs: [[credentialsId: '', url: 'git@github.com:monmichael32/AWS-Basic-infra.git']]]) 
    //  }  
   // }
    stage ('Terraform Shit') 
    {
        steps
        {
          sh '/usr/local/bin/terraform init -reconfigure'
          sh '/usr/local/bin/terraform apply --auto-approve'
          //sh 'terraform state show aws_instance.web-1 | grep public_ip | grep -v associate | awk -F\" \'{print \$2}\' >> ansible-apache/hosts'
          //sh 'terraform state show aws_instance.web-2 | grep public_ip | grep -v associate | awk -F\" \'{print \$2}\' >> ansible-apache/hosts'
          sh './inventory.sh'
          sh 'cd ansible-apache; ansible-playbook -vvv -i hosts apache.yml'
        }
    }  
  }
}
