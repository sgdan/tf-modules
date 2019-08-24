# desktop

An Ubuntu linux desktop allowing RDP login from Windows tunnelled over SSH.
Based on [How to Use a GUI with Ubuntu Linux on AWS EC2](https://www.youtube.com/watch?v=6x_okhl_CF4)

## Instructions

- Generate a new key using puttygen and save in `~/.ssh/<new-key>.ppk`
- Save the public key value so you can pass it to the module
- Deploy the module as part of your stack

  ```
  module "desktop" {
    source     = "github.com/sgdan/tf-modules//desktop?ref=0.4.0"
    vpc_id     = module.simple-vpc.vpc_id
    public_key = var.desktop_public_key
  }
  ```

- Connect via SSH to the instance using putty:
  - set `Session > Host Name` to `desktop.<your-domain>`
  - set `Connection > SSH > Auth > Private key file...` to the new private key file
  - set `Connection > Data > Auto-login username` to `ubuntu`
  - Set up tunnel in putty under `Connection > SSH > Tunnels`
    - Set `Source port` to `8888`
    - Set `Destination` to `internal..<your-domain>:3389` (using the domain you configured)
    - Click `Add`
  - IMPORTANT: Save session config before opening the session!
- Connect using putty to activate the tunnel
- Now use Remote Desktop to connect to "localhost:8888"
- Log in with ubuntu/ubuntu
