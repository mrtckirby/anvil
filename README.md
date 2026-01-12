# Anvil Community Server

Anvil is an automated community server system that creates user accounts on-demand when someone attempts to SSH into the server. Each user automatically gets their own web space and appears in a community directory.

## Features

- **Auto-Registration**: SSH with any username to automatically create an account
- **Personal Web Pages**: Each user gets `~/public_html` for their website
- **Community Directory**: Central page listing all users and their sites
- **FTP Access**: Both anonymous and authenticated FTP support
- **Secure by Default**: Users must change their password on first login

## Quick Start

### Prerequisites

- Fresh Ubuntu Server (20.04, 22.04, or 24.04)
- Root access
- Internet connection

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/mrtckirby/anvil.git
   cd anvil
   ```

2. **Run the installer:**
   ```bash
   sudo ./install.sh
   ```

3. **That's it!** Your Anvil server is ready.

## How It Works

### For Users

1. SSH to the server with any username:
   ```bash
   ssh alice@your-server-ip
   ```

2. Use the same username as the password when prompted
   (e.g., username: `alice`, password: `alice`)

3. You'll be forced to change your password immediately

4. Your personal website is now live at `http://your-server-ip/~alice/`

### For Administrators

The system consists of three main components:

1. **install.sh** - Installs dependencies and sets up the server
2. **setup.sh** - Configures PAM, SSH, web server, and FTP
3. **ssh-autocreate-user.sh** - The registration engine (runs via PAM hook)

#### What Gets Installed

- **OpenSSH Server** - For remote access
- **Lighttpd** - Lightweight web server with userdir support
- **vsftpd** - FTP server for file transfers
- **PAM Modules** - For the auto-registration hook

#### Security Considerations

⚠️ **This is designed for trusted communities or learning environments**, not production servers.

- Users can register with any available username
- Initial password equals username (changed on first login)
- All users get shell access
- FTP allows anonymous access

## Customization

### Modify User Welcome Page

Edit the template in `ssh-autocreate-user.sh` around line 28:

```bash
cat << WEBEOF > "$USER_HOME/public_html/index.html"
# Your custom HTML here
WEBEOF
```

### Change Community Directory Style

Edit the template in `setup.sh` around line 18:

```bash
cat << 'EOF' > /var/www/html/index.html
# Your custom HTML here
EOF
```

## Troubleshooting

### Users aren't being created automatically

Check the PAM configuration:
```bash
grep ssh-autocreate-user.sh /etc/pam.d/common-auth
```

### Web pages aren't showing

Verify Lighttpd userdir module:
```bash
lighttpd-enable-mod userdir
systemctl restart lighttpd
```

### Check the logs

```bash
# SSH authentication logs
tail -f /var/log/auth.log

# Web server logs
tail -f /var/log/lighttpd/error.log
```

## License

MIT License - Feel free to modify and distribute

## Contributing

Pull requests welcome! This is a community project.