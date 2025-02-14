# Devops practice exercise
## What is this?
This repository is the result of me working on a devops exercise to practice AWS infrastructure creation using Terraform, and the provisioning of Jenkins with Ansible.

The exact instructions where as follows:
```
Ejercicio: Usando terraform desplegar instancia y mediante ansible aprovisionar Jenkins.  

Requisitos:  

- Jenkins debe estar disponible en un load balancer (sugerido Application Load Balancer) 
- Desplegar networking, public y private subnets (VPC, Subnets, Internet Gateway) 
- Desplegar un bastion host que permitira la conexion al servidor de jenkins para tareas de mantenimiento  
- El servidor de jenkins no debe estar disponible via internet, solo a traves del load balancer (Usar private subnet) 
- Desplegar un NatGateway para que Jenkins puede tener acceso a internet para descargar actualizaciones y plugins, pero no de internet a Jenkins 
- Crear un pipeline sencillo usando groovy que haga el build de un proyecto cualquiera: que tipo de build 
 
Technologies suggested: AWS( EC2, IAM, ELB, VPC), Ansible, Terrraform 
```


## 0. AWS CLI installation
This setup assumes you've already installed AWS CLI V2. For detailed instructions on how to do it please see here: 
- https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html

## 1. IAM user
On the AWS console, create a new user and attach the "AmazonEC2FullAccess" policy to it. 

Create access keys with the "Command Line Interface" option selected and make note of the access key and and its secret (can't retrieve them later!). See here for more details:
 -  https://docs.aws.amazon.com/cli/latest/userguide/cli-authentication-user.html

## 2. Configure the IAM user on AWS CLI
On the terminal run the `aws configure` command and input your access key and secret when prompted, and also chose your default region. For example:

```
$ aws configure
AWS Access Key ID [None]: AKIAIOSFODNN7EXAMPLE
AWS Secret Access Key [None]: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
Default region name [None]: us-west-1
Default output format [None]: json
```

See here for more details:
 -  https://docs.aws.amazon.com/cli/latest/userguide/cli-authentication-user.html

 ## 3. Create a key pair
 You will also need to create a key pair to use it when configuring and accessing the bastion host and the private EC2 instance, so make sure not to lose the file or you won't be able to connect to them.

 To create your key pair simply search for "Key pairs" on the AWS console searchbar and you will find it on the EC2 service.

 Choose the "RSA" type, and ".pem" file format.

 Store the downloaded file on a memorable location in your local machine.

## 4. Terraform installation
For terraform installation instructions see here:
- https://developer.hashicorp.com/terraform/install


## 5. Running terraform
Open the "main.tf" file and locate the "locals" code block. 

- Replace the value for "key_name" with your own key name. IMPORTANT: Do not include the file extension, only the name. For example, if your key file is "my-key-pair.pem" the value for "key_name" would be "my-key-pair".

- Replace the value for "private_key_path" with the path to your own key.
- For "file_destination", replace only the name of the key with your own key, and do not remove the "/tmp/" prefix.
- For "chmod_command", replace only the name of the key with your own key, and do not remove the "/tmp/" prefix.

On your terminal, navigate to the directory where your cloned repository is and run the `terraform init` command.

Then run the `terraform apply` command and when prompted enter "yes" and Terraform will begin to create all the AWS resources.

### Ansible playbook
The Ansible playbook will run on its own as part of the `terraform apply` command and Jenkins will be installed. After Jenkins finishes installing you will be able to find the Jenkins password on the console. 

## 6. Accessing Jenkins
To access Jenkins navigate on the AWS console to EC2's "load balancers", find the the resource named "devops-alb", copy the its DNS name and access it on your browser.

The initial Jenkins setup will ask for a password, you will find it on the console after `terraform apply` has finished running.

If you can't find it, you will need to access the jenkins server (section 9) and run the following command:
- ` sudo cat /var/lib/jenkins/secrets/initialAdminPassword`

## 7. Fixing built-in node error
Once Jenkins has finished installing all the necessary plugins, you may find an error saying that the built-in node has been terminated due to a low disk space threshold alarm. You can disable the alarm by navigating to Manage Jenkins > System.
On "Global properties" click on the "Disk Space Monitoring Thresholds" checkbox and change the four inputs to "0GiB" and click on "Save".

Then navigate to Manage Jenkins > Nodes, and click on the "Built-In Node" link. Click on the "Configure" option from the sidebar, click on the "Disk Space Monitoring Thresholds" checkbox and change the four inputs to "0GiB" and click on "Save".

Then click on the "Bring this node back online" button, if an orange message saying "Disconnected by admin" appears just click again on the button and it should work.

## 8. Setting and running a Jenkins job
Click on the "New Item" option on the sidebar, and type in a name for your job.
- IMPORTANT: Avoid using whitespaces as Jenkins will create a directory with the name of your job.

Select "Pipeline" as the type of the job and click "Okay".

You may fill the information as needed, but to run a script from a Github repository scroll down to the "Pipeline" section and click on the "Definition" dropdown. Select "Pipeline script from SCM" and then on the "SCM" dropdown select "Git". 

Fill in the "Repository URL" input.

- For this example you may use this repository: https://github.com/rafael-encinas/jenkins-pipeline. It contains a single Jenkinsfile with a script that simply runs `echo` commands for each build step on the console.

 Then on "Branches to build" you may need to change the "Branch Specifier" to the branch where your Jenkinsfile is located, in our case change it to "*/main" and click on the "Save" button.

You will be redirected to your pipeline job, click on the "Build Now" option on the sidebar and it should run. 

To see how the console output click on the build from the "Builds" section, and then click on the "Console Output" option on the sidebar.


## 9. Server access (public bastion host and private jenkins server)
1. To access the bastion host for maintenance make sure to locate your key pair file.
2. Run the `chmod 400 "my-key.pem"` command, where you replace "my-key.pem" with your key file name.
3. Navigate on the AWS console and find the public IPv4 address for the EC2 instance called "devops_bastion_host".
4. Run the `ssh -i "my-key.pem" ec2-user@x.x.x.x` making sure to replace `x.x.x.x` with your bastion host Public IPv4 address.

The Terraform script will automatically copy the key pair file into the `/tmp` directory and run the `chmod 400 "my-key.pem"` command. 

If doing this manually you would need to create a file with the same name as your key pair, and copy the contents of your original key pair file into it.

### Accessing the private Jenkins server
5. SSH into the bastion host as described on steps 1-4 
6. Navigate on the AWS console and find the private IPv4 address for the EC2 instance called "devops_jenkins".
7. Once you're connected to the bastion host via SSH, run the `ssh -i "/tmp/my-key.pem" ec2-user@x.x.x.x` making sure to replace `x.x.x.x` with your jenkins server Private IPv4 address.


## 10. Deleting the AWS resources
To delete all the AWS resources created by Terraform simply run the `terraform destroy` command and enter "yes" when prompted.