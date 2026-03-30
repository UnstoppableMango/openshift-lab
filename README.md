# CI/CD Pipeline Runner

## Step 1: Install tooling

Minimum requirements:

- oc
- podman
- mssql-tools18
- gitlab-runner
- krb5-workstation
- helm

### Installation

- oc: [Install the oc CLI](https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/html/cli_tools/openshift-cli-oc#installing-openshift-cli)
- podman: `sudo dnf install podman`
- mssql-tools: [Set up SQL Server tools on Linux](https://learn.microsoft.com/en-us/sql/linux/sql-server-linux-setup-tools?view=sql-server-ver16&tabs=redhat-install%2Codbc-ubuntu-1804#install-tools-on-linux)
- gitlab-runner: [Install GitLab Runner](https://docs.gitlab.com/runner/install/linux-repository/?tab=RHEL%2FCentOS%2FFedora%2FAmazon+Linux#install-gitlab-runner)
- krb5-workstation: `sudo dnf install krb5-workstation`
- helm: [Install Helm](https://helm.sh/docs/intro/install#from-the-binary-releases)

## Step 2: Configure UID/GID mapping

1. Modify `/etc/subuid` so that the service account is allocated a sufficient UID range
1. Modify `/etc/subgid` so that the service account is allocated a sufficient GID range

For both UID and GID we can use `svc_account:2147483647:2147483648`, which allocates the top 2 billion *IDs as recommended by "Podman In Action"

## Step 3: Configure Kerberos

The RHEL9 VM profile has the minimum configuration to domain join the machine, we just need to configure the `kdc` and `admin_server`.

1. Create a new configuration file with the below contents at `/etc/krb5.conf.d/replaceme_conf_realm`
1. Ensure proper ownership with `sudo chown root:root /etc/krb5.conf.d/replaceme_conf_realm`
1. Ensure proper permissions with `sudo chmod a+r /etc/krb5.conf.d/replaceme_conf_realm`

## Step 4: Generate a keytab for the service account

In order to enable automated passwordless authentication, we need to store credentials for the service account on the runner machine.
This can be done securely using Kerberos and keytab files.

1. Create the Service Principal Name (SPN) for the runner account
1. Use `ktutil` to generate a keytab for the service account
    1. This tool provides its own read evaluate print loop (REPL) that is entered when executing the command
    1. Once inside the REPL, execute `addent -password -p svc_account@EXAMPLE.COM -k 11 -e aes256-cts-hmac-sha1-96 -s "EXAMPLE.COMsvcaccount/svc_account.example.com" params ""`
    1. Ensure the KVNO supplied to `-k` matches the current KVNO for the SPN in AD
    1. Ensure the salt supplied to `-s` matches the expected salt for the SPN
        1. The correct salt will be printed by `kinit` with the `-V` option and `KRB5_TRACE=/dev/stdout`
        1. i.e. `KRB5_TRACE=/dev/stdout kinit -V -k -t <keytab> svc_account`
    1. Still within the REPL, execute `wkt <path_to_keytab>` to write the keytab
    1. Use `quit` to exit the REPL
1. Move the keytab file to `/var/kerberos/krb5/user/<uid>/client.keytab`
    1. `<uid>` can be obtained with `id svc_account`
1. Ensure proper directory an file ownership
    1. `chown svc_account:g-ad-group-default_svc-acct_group /var/kerberos/krb5/user/<uid>`
    1. `chown svc_account:g-ad-group-default_svc-acct_group /var/kerberos/krb5/user/<uid>/client.keytab`

## Step 5: Configure the GitLab runner

We'll create a project-scoped runner to ensure only the expected projects can execute jobs on the runner, and therefore access secrets granted to the runner.

1. Create work directory for runner
    1. `mkdir -p /home/gitlab-runner`
    1. `chown svc_account:g-ad-group-default_svc-acct_group /home/gitlab-runner`
    1. Ensure this home directory does not contain any `bash` profile files, these cause issues during job execution
1. Enable creating project-scoped runners
    1. Navigate to the GitLab Admin panel
    1. Navigate to CI/CD Settings -> Runners
    1. Check the box "Members of the project can create runners"
        1. Post-runner registration, this option can be disabled
1. Register runner with GitLab
    1. Navigate to the project that will consume the runner i.e. `ai-ops/cluster-configuration`
    1. Navigate to Settings -> CI/CD
    1. Expand "Runners"
    1. Click "Create Project Runner" in the upper right-hand corner
    1. Select "Run untagged"
    1. Click "Create" and note the token in a secure location
1. Create the runner configuration file
    1. When `gitlab-runner` was installed it will have created a default configuration file at `/etc/gitlab-runner/config.toml`
    1. Add a `[[runners]]` section with `name` and `token` fields
    1. The value for `name` should follow the form `openshift-<environment>`, i.e. `openshift-dev`
    1. Use the token value from the previous step for `token`
1. Create the `systemd` service file
    1. When `gitlab-runner` was installed it will have created a default service file at `/etc/systemd/system/gitlab-runner.service`
        1. This file will get overritten when the server is patched, so we need to provide an override file instead
    1. Create a new directory `mkdir -p /etc/systemd/system/gitlab-runner.service.d/`
    1. Create a new file `/etc/systemd/system/gitlab-runner.service.d/svc_account.conf`
    1. Apply the file contents from [below](#etcsystemdsystemgitlab-runnerserviceddsvc_gitrunnerconf)
        1. The file name and `--user` option should match the name of the service account
        1. The first `ExecStart` clears the original value so we can override it
        1. he `EnvironmentFile` directive is cleared as a safeguard
1. Enable and start the `systemd` service using `sudo systemctl enable --now gitlab-runner.service`
1. Confirm the newly registered runner appears in the project runners panel
