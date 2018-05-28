
```bash
brew install gpg
# execute gpg --list-keys to create trustdb.gpg
gpg --list-keys

cat >maven_gpg_key_with_default_algorithms <<EOF
%echo Generating a default key
# Key-Type: DSA
Key-Type: default
Key-Length: 2048
# Subkey-Type: ELG-E
Subkey-Type: default
Name-Real: home1 oss
Name-Comment: with passphrase
Name-Email: opensource@home1.cn
Expire-Date: 0
Passphrase: <passphrase>
%pubring codesigning.pub
%secring codesigning.sec
# Do a commit here, so that we can later print "done" :-)
%commit
%echo done
EOF

# gpg 2.x will not generate maven_gpg_key.sec file
gpg --batch --gen-key maven_gpg_key_with_default_algorithms
gpg --import codesigning.pub
# List public keys
gpg --list-keys
# List private keys
gpg --list-secret-keys

# see: https://andreas.heigl.org/2017/01/19/encrypt-a-build-result-automaticaly/
# i.e. B24F8E5A595250B60381765A869445475A70DAC8
export CI_OPT_GPG_KEYNAME=$(gpg --list-secret-keys | grep -E '[A-Z0-9]{16,}')
# i.e. 869445475A70DAC8
echo ${CI_OPT_GPG_KEYNAME: -16}

# To make the key accessible for others we should now send it to a keyserver.
gpg --keyserver pgp.mit.edu --send-key ${CI_OPT_GPG_KEYNAME}

# We can also already generate a revocation certificate for the key.
# Should the key be compromised I can send the revocation certificate to the keyserver to invalidate the signing key.
gpg --output revoke-${CI_OPT_GPG_KEYNAME: -16}.asc --gen-revoke ${CI_OPT_GPG_KEYNAME: -16}

gpg --export -a ${CI_OPT_GPG_KEYNAME} > codesigning.asc
gpg --export-secret-key -a ${CI_OPT_GPG_KEYNAME} >> codesigning.asc
# get a codesigning.asc.gpg
gpg -c codesigning.asc

# see: https://docs.travis-ci.com/user/encrypting-files/
travis encrypt-file codesigning.asc
openssl aes-256-cbc -K $encrypted_0a6446eb3ae3_key -iv $encrypted_0a6446eb3ae3_iv -in codesigning.asc.enc -out codesigning.asc -d
```
