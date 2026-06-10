# OperaLinux Build Script

Bootstrap per creare una ISO OperaLinux partendo da Arch Linux.

Comando rapido completo, per partire da Arch e usare repo Artix-first:

```sh
curl -fsSL https://raw.githubusercontent.com/OperaLinux/build-script/main/bootstrap.sh | sudo OPERALINUX_CHANGE_HOST_REPOS=1 bash
```

Lo script:

- fa backup della configurazione pacman;
- cambia le repo host in Artix-first dopo conferma;
- installa le dipendenze di build mancanti;
- importa la keyring Artix con `--nodeps`, evitando il conflitto `artix-mirrorlist` / `pacman-mirrorlist`;
- clona `https://github.com/OperaLinux/build.git`;
- esegue `sudo ./build.sh`;
- copia la ISO finale nella directory da cui hai lanciato il comando.

Output:

```text
OperaLinux-x86_64.iso
```

Modalita meno invasiva, senza cambiare `/etc/pacman.conf`:

```sh
curl -fsSL https://raw.githubusercontent.com/OperaLinux/build-script/main/bootstrap.sh | sudo bash
```

Il backup di `/etc/pacman.conf` e delle mirrorlist viene salvato in:

```text
/var/backups/operalinux-build-script/
```

Per saltare il download automatico di Proton GE durante la build:

```sh
curl -fsSL https://raw.githubusercontent.com/OperaLinux/build-script/main/bootstrap.sh | sudo INSTALL_PROTON_GE=0 bash
```

Se GitHub o DNS non sono disponibili dentro la chroot, la build continua e
`update-proton-ge` resta installato nella ISO per aggiornare Proton GE dopo il
boot.

Se durante l'installazione di `yay-bin` compare:

```text
could not determine root mount point /
not enough free disk space
```

aggiorna la repo `https://github.com/OperaLinux/build/`: il builder disattiva
temporaneamente `CheckSpace` solo durante l'installazione di yay nella chroot e
lo ripristina subito dopo.

Se compare:

```text
config file /etc/pacman.d/mirrorlist-arch could not be read
```

aggiorna la repo `https://github.com/OperaLinux/build/`: il builder deve generare
un `pacman.conf` temporaneo con mirrorlist locali al checkout, senza dipendere
dai file pacman dell'host.
