
## I. Install GPG

install (OSX `brew install gpg`) and run `gpg --list-keys to create trustdb.gpg`

## II .Generate GPG keys

### 1. Create keypair
```bash
cat >maven_gpg_key_with_default_algorithms <<EOF
%echo Generating a default key
# Key-Type: DSA
Key-Type: default
Key-Length: 2048
# Subkey-Type: ELG-E
Subkey-Type: default
Name-Real: home1 oss
Name-Comment: with passphrase
Name-Email: ossrh@home1.cn
Expire-Date: 0
Passphrase: <passphrase>
%pubring codesigning.pub
%secring codesigning.sec
# Do a commit here, so that we can later print "done" :-)
%commit
%echo done
EOF

gpg --batch --gen-key maven_gpg_key_with_default_algorithms
gpg --import codesigning.pub
```

### 2. Find the key just created

```bash
# List public keys
gpg --list-keys
# List private keys
gpg --list-secret-keys

# i.e. B24F8E5A595250B60381765A869445475A70DAC8
export CI_OPT_GPG_KEYNAME=$(gpg --list-secret-keys | grep -E '[A-Z0-9]{16,}')
# i.e. 869445475A70DAC8
echo ${CI_OPT_GPG_KEYNAME: -16}
# gpg1
# i.e. 5A70DAC8
echo ${CI_OPT_GPG_KEYNAME: -8}
```

### 3. Send to keyserver

To make the key accessible for others we should now send it to a keyserver.

```bash
gpg --send-key ${CI_OPT_GPG_KEYNAME} --keyserver hkp://pool.sks-keyservers.net
gpg --send-key ${CI_OPT_GPG_KEYNAME} --keyserver hkp://keys.gnupg.net
gpg --send-key ${CI_OPT_GPG_KEYNAME} --keyserver keyserver.pgp.com
gpg --send-key ${CI_OPT_GPG_KEYNAME} --keyserver pgp.mit.edu
gpg --send-key ${CI_OPT_GPG_KEYNAME} --keyserver ha.pool.sks-keyservers.net

# We can also already generate a revocation certificate for the key.
# Should the key be compromised I can send the revocation certificate to the keyserver to invalidate the signing key.
gpg --output revoke-${CI_OPT_GPG_KEYNAME: -16}.asc --gen-revoke ${CI_OPT_GPG_KEYNAME: -16}
```

## III. Export keys (Get codesigning.asc)

```bash
gpg --export -a ${CI_OPT_GPG_KEYNAME} > codesigning.pub
gpg --export-secret-key -a ${CI_OPT_GPG_KEYNAME} > codesigning.asc
#gpg --export-secret-keys -a ${CI_OPT_GPG_KEYNAME} > codesigning.asc
```

## Iv. Encrypt the key and make it available to CI (i.e. travis-ci)

### 1. General way
see: https://andreas.heigl.org/2017/01/19/encrypt-a-build-result-automaticaly/
```bash
# get a encrypted codesigning.asc.gpg
echo ${CI_OPT_GPG_PASSPHRASE} | gpg --yes --passphrase-fd 0 --use-agent --cipher-algo AES256 -o codesigning.asc.gpg -c codesigning.asc
# decrypt
echo ${CI_OPT_GPG_PASSPHRASE} | gpg --yes --passphrase-fd 0 codesigning.asc.gpg

# import
gpg --yes --batch --import codesigning.asc

# set default key
# interactively
gpg --yes --edit-key ${CI_OPT_GPG_KEYNAME} trust quit
# non-interactively
# see: https://blog.tersmitten.nl/how-to-ultimately-trust-a-public-key-non-interactively.html
echo -e "trust\n5\ny\n" | gpg --command-fd 0 --edit-key ${CI_OPT_GPG_KEYNAME}

# test
echo ${CI_OPT_GPG_PASSPHRASE} | gpg --yes --passphrase-fd 0 -u ${CI_OPT_GPG_KEYNAME} --armor --detach-sig target/checkstyle-result.xml
```

### 2. travis-ci way
see: https://docs.travis-ci.com/user/encrypting-files/
```bash
# cd project (repository) root, then encrypt
travis encrypt-file codesigning.asc
# decrypt
openssl aes-256-cbc -K $encrypted_0a6446eb3ae3_key -iv $encrypted_0a6446eb3ae3_iv -in codesigning.asc.enc -out codesigning.asc -d
# import
gpg --fast-import codesigning.asc
```

## IV. issues

### 1. To fix issue: gpg: signing failed: Inappropriate ioctl for device
1.1.
    ~/.gnupg/gpg.conf:
    use-agent
    pinentry-mode loopback
1.2.
    ~/.gnupg/gpg-agent.conf:
    allow-loopback-pinentry
1.3.
    echo RELOADAGENT | gpg-connect-agent

### 2. travis-ci (dist: trusty)
```yaml
addons:
  apt:
    packages:
    - gnupg
    - gnupg2
```
some versions not working on decrypt AES files (encrypted on OSX with gpg1)

Install gpg1 on OSX
```
brew unlink gpg2
brew install gpg1
export PATH="/usr/local/opt/gnupg@1.4/libexec/gpgbin:$PATH"
gpg --version
```

use openssl instead

openssl aes-256-cbc -k ${CI_OPT_GPG_PASSPHRASE} -salt -in codesigning.asc -out codesigning.asc.enc -e
openssl aes-256-cbc -k ${CI_OPT_GPG_PASSPHRASE} -in codesigning.asc.enc -out codesigning.asc -d
