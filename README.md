VCWC: Versioning Competition Workflow Compiler
==============================================


```
git clone https://github.com/tkren/vcwc.git
cd vcwc
cp trackinfo-t01.mk trackinfo-tNN.mk
```

Then edit content of `trackinfo-tNN.mk` to fit your needs.

Benchmark directories
---------------------

Create `benchmarks/tNN/bBB` directories with the encondings.

> It's best if you symlink those benchmark directories to a repository.

Participant image
-----------------

Create a sandbox image with

```
mkdir ./sandbox && sudo debootstrap --arch=amd64 precise ./sandbox http://at.archive.ubuntu.com/ubuntu/
```

> See also [https://wiki.debian.org/Debootstrap].

If software is missing for the participant solver within the base system, you can update the sandbox with

```
chroot ./sandbox
mount -t proc proc /proc && mount -t sysfs sysfs /sys && mount -t devtmpfs udev /dev && mount -t devpts devpts /dev/pts
# install stuff with apt-get or copy files
umount /proc && umount /sys && umount /dev/pts && umount /dev
exit
```

Then run

```
tar -c ./sandbox > software/sandbox-with-fancy-software.tar
```

to create the base tarball that will be used to create the participant images.

Next create the `participants/tNN` directory and run `vcwc/lib/create_all_tracks.sh`.

**FIXME**
