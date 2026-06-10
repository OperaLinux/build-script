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
