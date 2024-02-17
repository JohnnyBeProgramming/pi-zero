read -p 'Git user email: ' email

ssh-keygen -t ed25519 -C $email

eval "$(ssh-agent -s)"

if [ ! -f ~/.ssh/config ]
then
    cat << EOF >> ~/.ssh/config
Host github.com
  AddKeysToAgent yes
  IdentityFile ~/.ssh/id_ed25519
EOF
fi

echo "TODO: Add this ssh key to your GitHub account"
echo "----------------------------------------------"
cat ~/.ssh/id_ed25519.pub
echo "----------------------------------------------"
echo "Press enter when ready to test connection..."
read

while ! ssh -T git@github.com
do
    sleep 3
done
