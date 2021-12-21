github.com/openshifit/installer 수행시

### 1. terraform install 
참고 사이트: https://learn.hashicorp.com/tutorials/terraform/install-cli 

On CenOS/RHEL
$ sudo yum install -y yum-utils
$ sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
$ sudo yum -y install terraform
$ terraform version

### 2. upi/vsphere dir에서 terraform init 수행
[root@bastion vsphere]# terraform init
Initializing modules...

Initializing the backend...

Initializing provider plugins...
- Finding latest version of hashicorp/vsphere...
- Finding latest version of hashicorp/ignition...
- Finding latest version of hashicorp/aws...
- Finding latest version of hashicorp/null...
- Finding latest version of hashicorp/http...
- Installing hashicorp/aws v3.70.0...
- Installed hashicorp/aws v3.70.0 (signed by HashiCorp)
- Installing hashicorp/null v3.1.0...
- Installed hashicorp/null v3.1.0 (signed by HashiCorp)
- Installing hashicorp/http v2.1.0...
- Installed hashicorp/http v2.1.0 (signed by HashiCorp)
- Installing hashicorp/vsphere v2.0.2...
- Installed hashicorp/vsphere v2.0.2 (signed by HashiCorp)
╷
│ Error: Failed to query available provider packages
│
│ Could not retrieve the list of available versions for provider hashicorp/ignition: provider
│ registry registry.terraform.io does not have a provider named
│ registry.terraform.io/hashicorp/ignition
│
│ Did you intend to use terraform-providers/ignition? If so, you must specify that source address in
│ each module which requires that provider. To see which modules are currently depending on
│ hashicorp/ignition, run the following command:
│     terraform providers

availale provider pakage error 발생
provider hashicorp/ignition가 없어서 발생하는 에러
실제 hashicorp/ignition provider는 존재하지 않으며, https://registry.terraform.io/providers/community-terraform-providers/ignition/latest 로 변경됨.

### 3. plugins provider downlaod 및 setup
binary module을 dowload하기 위해서 source code가 있는 github로 이동 
( https://github.com/community-terraform-providers/terraform-provider-ignition )
오른쪽에서 최신 release click -> OS System에 맞는 artifact download

$ cd Download
$ wget https://github.com/community-terraform-providers/terraform-provider-ignition/releases/download/v1.3.0/terraform-provider-ignition_1.3.0_linux_amd64.zip
$ unzip terraform-provider-ignition_2.1.2_linux_amd64.zip terraform-provider-ignition_v2.1.2

terraform plugins dircetory에 mv
$ mkdir -p ~/.terraform.d/plugins/community-terraform-providers/ignition/2.1.2/
$ mv terraform-provider-ignition_v2.1.2 ~/.terraform.d/plugins/community-terraform-providers/ignition/2.1.2

provider 등록. ( 참고: https://www.terraform.io/language/providers/requirements )
$ cd upi/vsphere
$ vi version.tf
terraform {
  required_providers {
    ignition = {
      source = "community-terraform-providers/ignition"
      version = "2.1.2"
    }
  }
}

$ main.tf 수정
provider "ignition" block에서 version 항목 삭제
# force local ignition provider binary
provider "ignition" {
}

terraform init을 수행할 때 마다 current directory의 .terraform dir에  provider를 download하므로
성능과 중복 방지를 위해 .terraformrc file파일을 만들어 cache 설정을 한다.
$ vi ~/.terraformrc
plugin_cache_dir   = "$HOME/.terraform.d/plugin-cache"
disable_checkpoint = true

$ terraform init
Error: Failed to query available provider packages
│
│ Could not retrieve the list of available versions for provider hashicorp/ignition: provider
│ registry registry.terraform.io does not have a provider named
│ registry.terraform.io/hashicorp/ignition
│
│ Did you intend to use community-terraform-providers/ignition? If so, you must specify that source
│ address in each module which requires that provider. To see which modules are currently depending
│ on hashicorp/ignition, run the following command:
│     terraform providers

어느 하위 모듈에서 ignition provider를 사용하는지 알아보기 위해 위 message 처럼 terraform providers 수행
$ terraform providers
Providers required by configuration:
.
├── provider[registry.terraform.io/community-terraform-providers/ignition] 2.1.2
├── provider[registry.terraform.io/hashicorp/vsphere]
├── module.control_plane_a_records
│   └── provider[registry.terraform.io/hashicorp/aws]
├── module.ipam_bootstrap
│   ├── provider[registry.terraform.io/hashicorp/null]
│   └── provider[registry.terraform.io/hashicorp/http]
├── module.lb_vm
│   └── provider[registry.terraform.io/hashicorp/vsphere]
├── module.bootstrap
│   └── provider[registry.terraform.io/hashicorp/vsphere]
├── module.compute_a_records
│   └── provider[registry.terraform.io/hashicorp/aws]
├── module.compute_vm
│   └── provider[registry.terraform.io/hashicorp/vsphere]
├── module.ipam_control_plane
│   ├── provider[registry.terraform.io/hashicorp/http]
│   └── provider[registry.terraform.io/hashicorp/null]
├── module.lb_a_records
│   └── provider[registry.terraform.io/hashicorp/aws]
├── module.ipam_lb
│   ├── provider[registry.terraform.io/hashicorp/http]
│   └── provider[registry.terraform.io/hashicorp/null]
├── module.lb
│   └── provider[registry.terraform.io/hashicorp/ignition]
├── module.control_plane_vm
│   └── provider[registry.terraform.io/hashicorp/vsphere]
├── module.dns_cluster_domain
│   └── provider[registry.terraform.io/hashicorp/aws]
└── module.ipam_compute
    ├── provider[registry.terraform.io/hashicorp/null]
    └── provider[registry.terraform.io/hashicorp/http]


module.lb에서 igniton provider 사용
따라서, lb module에서 required_providers 설정 필요.
$ cp version.tf lb/.
[root@bastion vsphere]# terraform providers

Providers required by configuration:
.
├── provider[registry.terraform.io/community-terraform-providers/ignition] 2.1.2
├── provider[registry.terraform.io/hashicorp/vsphere]
├── module.control_plane_a_records
│   └── provider[registry.terraform.io/hashicorp/aws]
├── module.ipam_bootstrap
│   ├── provider[registry.terraform.io/hashicorp/null]
│   └── provider[registry.terraform.io/hashicorp/http]
├── module.lb
│   └── provider[registry.terraform.io/community-terraform-providers/ignition] 2.1.2
├── module.compute_a_records
│   └── provider[registry.terraform.io/hashicorp/aws]
├── module.ipam_compute
│   ├── provider[registry.terraform.io/hashicorp/null]
│   └── provider[registry.terraform.io/hashicorp/http]
├── module.dns_cluster_domain
│   └── provider[registry.terraform.io/hashicorp/aws]
├── module.control_plane_vm
│   └── provider[registry.terraform.io/hashicorp/vsphere]
├── module.compute_vm
│   └── provider[registry.terraform.io/hashicorp/vsphere]
├── module.ipam_control_plane
│   ├── provider[registry.terraform.io/hashicorp/null]
│   └── provider[registry.terraform.io/hashicorp/http]
├── module.lb_a_records
│   └── provider[registry.terraform.io/hashicorp/aws]
├── module.bootstrap
│   └── provider[registry.terraform.io/hashicorp/vsphere]
├── module.lb_vm
│   └── provider[registry.terraform.io/hashicorp/vsphere]
└── module.ipam_lb
    ├── provider[registry.terraform.io/hashicorp/null]
    └── provider[registry.terraform.io/hashicorp/http]

초기화 실행
[root@bastion vsphere]# terraform init
Initializing modules...

Initializing the backend...

Initializing provider plugins...
- Finding latest version of hashicorp/http...
- Finding latest version of hashicorp/aws...
- Finding community-terraform-providers/ignition versions matching "2.1.2"...
- Finding latest version of hashicorp/vsphere...
- Finding latest version of hashicorp/null...
- Installing hashicorp/http v2.1.0...
- Installed hashicorp/http v2.1.0 (signed by HashiCorp)
- Installing hashicorp/aws v3.70.0...
- Installed hashicorp/aws v3.70.0 (signed by HashiCorp)
- Installing community-terraform-providers/ignition v2.1.2...
- Installed community-terraform-providers/ignition v2.1.2 (self-signed, key ID 13D373249FD8E4D3)
- Installing hashicorp/vsphere v2.0.2...
- Installed hashicorp/vsphere v2.0.2 (signed by HashiCorp)
- Installing hashicorp/null v3.1.0...
- Installed hashicorp/null v3.1.0 (signed by HashiCorp)

Partner and community providers are signed by their developers.
If you'd like to know more about provider signing, you can read about it here:
https://www.terraform.io/docs/cli/plugins/signing.html

Terraform has created a lock file .terraform.lock.hcl to record the provider
selections it made above. Include this file in your version control repository
so that Terraform can guarantee to make the same selections by default when
you run "terraform init" in the future.

Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.
