provider "aws" {
  region = "ap-south-1"
  }
resource "aws_instance" "test" {
  count = 2
  ami                    = var.ami
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = var.vpc_security_group_ids
  subnet_id              = var.subnet_id
  iam_instance_profile = data.aws_iam_instance_profile.test8.name
  instance_initiated_shutdown_behavior = "terminate"
  associate_public_ip_address = var.associate_public_ip_address
user_data =  <<-EOF
                <powershell>
$domain_name = "1hclplm".ToUpper()
$domain_tld = "local"
$secrets_manager_secret_id = "dev/devops/devopsadmin"
$secret_manager = Get-SECSecretValue -SecretId $secrets_manager_secret_id
$path = "C:\setup"
# Parse the response and convert the Secret String JSON into an object
$secret = $secret_manager.SecretString | ConvertFrom-Json

# Construct the domain credentials
$username = $domain_name.ToUpper() + "\" + $secret.username
$password = $secret.Password | ConvertTo-SecureString -AsPlainText -Force

# Get the hostname from the metadata store, we will use this as our computer name during domain registration.
$computername = (get-childitem env:COMPUTERNAME).value
Write-Output $computername


#enable insecure guest logons through GPO or local policy
Set-ItemProperty -Path Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters "AllowInsecureGuestAuth" -Value '1'

# Set PS credentials
$credential = New-Object System.Management.Automation.PSCredential($username,$password)
New-PSDrive –Name “D” –PSProvider FileSystem –Root “\\172.18.81.123\Setup” -Credential $credential –Persist

msiexec /package "D:\amazon-corretto-11.0.13.8.1-windows-x64.msi" /quiet  INSTALLDIR=C:\Apps\Java\
[Environment]::SetEnvironmentVariable("JRE_HOME","C:\Apps\Java\jdk11.0.13.8.1","Machine")
[Environment]::SetEnvironmentVariable("JAVA_HOME","C:\Apps\Java\jdk11.0.13.8.1","Machine")
Copy-Item -Path "D:\apache-tomcat" -Destination "C:\Apps\" -Recurse
Copy-Item -Path "D:\test.sql" -Destination "C:\Apps\" -Recurse
sqlcmd -S $computername -E -i "C:\Apps\test.sql"

cd C:\Apps\bin\
.\service.bat install
sc.exe config Tomcat9 start=auto

# Perform the domain join
$domainjoin = Add-Computer -DomainName "$domain_name.$domain_tld" -Credential $credential -Passthru -Verbose -Force -Restart

                </powershell>
                 EOF
tags = {
   Name = "Server ${count.index}"
}

}

data "aws_iam_instance_profile" "test8" {
           name = "test8"
          #  role = "custom-ec2-domain-join-role"
 }
 #    data "aws_iam_role" "role" {
 #    name = "custom-ec2-domain-join-role"
 #}
 