echo "Leave default file path and press enter"
ssh-keygen -t ed25519 -C "luca.mas93@gmail.com"
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

echo "Public key for GitHub:"
cat ~/.ssh/id_ed25519.pub

echo
echo "Public key for GitHub copied to clipboard"
if command -v clip.exe &> /dev/null
then
    CLIPCMD=clip.exe
else
    CLIPCMD=clip
fi

$CLIPCMD < ~/.ssh/id_ed25519.pub