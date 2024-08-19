# Скрипт для автоматического удаления из системы депрезентованных дисков с СХД

- [Скрипт для автоматического удаления из системы депрезентованных дисков с СХД](#скрипт-для-автоматического-удаления-из-системы-депрезентованных-дисков-с-схд)
- [Подробное описание](#подробное-описание)
- [Используемые функции в данном скрипте](#используемые-функции-в-данном-скрипте)
- [Функциональные возможности скрипта](#функциональные-возможности-скрипта)
- [Проверка логов в системе](#проверка-логов-в-системе)
- [Примеры запуска](#примеры-запуска)
  - [Удаление устройства по wwid](#удаление-устройства-по-wwid)
  - [Удаление устройства по alias](#удаление-устройства-по-alias)
  - [Удаление используемого устройства](#удаление-используемого-устройства)
  - [Удаление несуществующего устройства](#удаление-несуществующего-устройства)

# Подробное описание
Скрипт предназначен для удаления мультипас устройств в системе linux.  
Под удалением подразумевается удаление всех путей мультипас-устройства и самого логического устройства из системы.

Скрипт учитывает все опасные ситуации связанные с удалением существующих и активных дисков.

# Используемые функции в данном скрипте
- [is_command_exists](doc/functions.md#is_command_exists)
- [is_module_loaded](doc/functions.md#is_module_loaded)
- [is_systemd_service_exists](doc/functions.md#is_systemd_service_exists)
- [is_systemd_service_active](doc/functions.md#is_systemd_service_active)
- [remove_record](doc/functions.md#remove_record)
- [clear_mpio_record](doc/functions.md#clear_mpio_record)
- [is_multipath_device](doc/functions.md#is_multipath_device)
- [mpio_wwid_to_dm](doc/functions.md#mpio_wwid_to_dm)
- [mpio_alias_to_wwid](doc/functions.md#mpio_alias_to_wwid)
- [is_device_busy](doc/functions.md#is_device_busy)
- [is_mpio_device_exists](doc/functions.md#is_mpio_device_exists)
- [is_device_in_lvm](doc/functions.md#is_device_in_lvm)
- [описание логирования](doc/logging.md)

# Функциональные возможности скрипта
- **Проверяется наличие в памяти ядра модуля dm_multipath**
- **Выполняется проверка существования сервиса multipathd**
- **Проверяется что девайс является мультипас-устройством**
- **Выполняется проверка что удаляемое устройство ни кем не используется**
- **Выполняется удаление алиасов и других опций из конфигурационных файлов**
- **Выполняется сброс буферов на диск**
- **Выполняется удаление всех путей принадлежащих мультипас-устройству**
- **Выполняется резервное копирование конфигураций перед деструктивными действиями**
- **Выполняется полное логирование всех действий и вывод информации в журнал**

# Проверка логов в системе
Пример для journalctl:

```shell
[root@simple-host ~]# journalctl --since today | grep 'rmpio.sh'
Jul 24 23:00:53 simple-host.example.com rmpio.sh[36663]: found 'dmsetup' command
Jul 24 23:00:53 simple-host.example.com rmpio.sh[36664]: found 'multipathd' command
Jul 24 23:00:53 simple-host.example.com rmpio.sh[36665]: found 'blockdev' command
Jul 24 23:00:53 simple-host.example.com rmpio.sh[36668]: Module dm_multipath is loaded
Jul 24 23:00:53 simple-host.example.com rmpio.sh[36671]: systemd service multipathd exists
Jul 24 23:00:53 simple-host.example.com rmpio.sh[36673]: systemd service multipathd is active
Jul 24 23:00:53 simple-host.example.com rmpio.sh[36681]: The device '3624a93705598f4dec0624d4e000113f2' doesn't have alias
Jul 24 23:00:53 simple-host.example.com rmpio.sh[36689]: Device wwid: 3624a93705598f4dec0624d4e000113f2
Jul 24 23:00:53 simple-host.example.com rmpio.sh[36690]: Device alias: 3624a93705598f4dec0624d4e000113f2
Jul 24 23:00:53 simple-host.example.com rmpio.sh[36691]: Device dm path: /dev/dm-4
Jul 24 23:00:53 simple-host.example.com rmpio.sh[36694]: The device 3624a93705598f4dec0624d4e000113f2 (3624a93705598f4dec0624d4e000113f2) is multipath device
Jul 24 23:00:53 simple-host.example.com rmpio.sh[36699]: The device 3624a93705598f4dec0624d4e000113f2 (3624a93705598f4dec0624d4e000113f2) not busy
Jul 24 23:00:53 simple-host.example.com rmpio.sh[36706]: flushed buffers for /dev/dm-4
Jul 24 23:00:53 simple-host.example.com rmpio.sh[36725]: The next paths were removed: sdp sdl sdh sdd
```

# Примеры запуска

## Удаление устройства по wwid

Текущее состояние конфигурации в памяти:
```shell
[root@simple-host ~]# multipath -ll | grep -i dm- | awk '{print $1 " " $2}' | sort -k1,1
DATA01-LUN22 (3624a93708618258ed4c4d30a00011493)
DATA02-LUN22 (3624a93708618258ed4c4d30a00011494)
DATA03-LUN22 (3624a93708618258ed4c4d30a00011492)
DATA04-LUN22 (3624a93708618258ed4c4d30a00011491)
DATA06-LUN22 (3624a93705598f4dec0624d4e000113f0)
DATA07-LUN22 (3624a93705598f4dec0624d4e000113f1)
DATA08-LUN22 (3624a93705598f4dec0624d4e000113f2)
DATA09-LUN22 (3624a93705598f4dec0624d4e000113f3)
```

Текущее состояние конфигурации в конфиге (/etc/multipath.conf):
```shell
multipaths {
    multipath {
               wwid  3624a93705598f4dec0624d4e000113f0
               alias DATA06-LUN22
               }

    multipath {
               wwid  3624a93705598f4dec0624d4e000113f1
               alias DATA07-LUN22
               }
    ... (и т.д)
```

включение самого высокого уровня логирования (debug):
```shell
export VERBOSE=6
```

Удаление устройства (DATA06-LUN22 3624a93705598f4dec0624d4e000113f0):
```shell
[root@simple-host ~]# ./rmpio.sh --wwid 3624a93705598f4dec0624d4e000113f0
rmpio.sh[12747]: found 'dmsetup' command
rmpio.sh[12747]: found 'multipathd' command
rmpio.sh[12747]: found 'blockdev' command
rmpio.sh[12747]: Module dm_multipath is loaded
rmpio.sh[12747]: systemd service multipathd exists
rmpio.sh[12747]: systemd service multipathd is active
rmpio.sh[12747]: Device wwid: 3624a93705598f4dec0624d4e000113f0
rmpio.sh[12747]: Device alias: DATA06-LUN22
rmpio.sh[12747]: Device dm path: /dev/dm-5
rmpio.sh[12747]: The device 3624a93705598f4dec0624d4e000113f0 (DATA06-LUN22) is multipath device
rmpio.sh[12747]: The device 3624a93705598f4dec0624d4e000113f0 (DATA06-LUN22) not busy
rmpio.sh[12747]: Created directory for backup: /tmp/tmp.581qS7izL2
rmpio.sh[12747]: Backup file for /etc/multipath.conf was created in /tmp/tmp.581qS7izL2/multipath.conf_2024-07-25_01:59:08
rmpio.sh[12747]: flushed buffers for /dev/dm-5
rmpio.sh[12747]: The next paths were removed: sdr sdn sdj sdf
```

Подтверждение выполененых действий:
```shell
[root@simple-host ~]# diff /etc/multipath.conf /tmp/tmp.581qS7izL2/multipath.conf_2024-07-25_01:59:08
11a12,15
>     multipath {
>                wwid  3624a93705598f4dec0624d4e000113f0
>                alias DATA06-LUN22
>                }


[root@simple-host ~]# multipath -ll | grep -i dm- | awk '{print $1 " " $2}' | sort -k1,1
DATA01-LUN22 (3624a93708618258ed4c4d30a00011493)
DATA02-LUN22 (3624a93708618258ed4c4d30a00011494)
DATA03-LUN22 (3624a93708618258ed4c4d30a00011492)
DATA04-LUN22 (3624a93708618258ed4c4d30a00011491)
DATA07-LUN22 (3624a93705598f4dec0624d4e000113f1)
DATA08-LUN22 (3624a93705598f4dec0624d4e000113f2)
DATA09-LUN22 (3624a93705598f4dec0624d4e000113f3)
```

## Удаление устройства по alias

Текущее состояние конфигурации в памяти:
```shell
[root@simple-host ~]# multipath -ll | grep -i dm- | awk '{print $1 " " $2}' | sort -k1,1
DATA01-LUN22 (3624a93708618258ed4c4d30a00011493)
DATA02-LUN22 (3624a93708618258ed4c4d30a00011494)
DATA03-LUN22 (3624a93708618258ed4c4d30a00011492)
DATA04-LUN22 (3624a93708618258ed4c4d30a00011491)
DATA07-LUN22 (3624a93705598f4dec0624d4e000113f1)
DATA08-LUN22 (3624a93705598f4dec0624d4e000113f2)
DATA09-LUN22 (3624a93705598f4dec0624d4e000113f3)
```

Текущее состояние конфигурации в конфиге (/etc/multipath.conf):
```shell
multipaths {
    multipath {
               wwid  3624a93705598f4dec0624d4e000113f1
               alias DATA07-LUN22
               }

    multipath {
               wwid  3624a93705598f4dec0624d4e000113f2
               alias DATA08-LUN22
               }
    ... (и т.д)
```

Удаление устройства (DATA07-LUN22 3624a93705598f4dec0624d4e000113f1):
```shell
[root@simple-host ~]# ./rmpio.sh --alias DATA07-LUN22
rmpio.sh[40665]: Created directory for backup: /tmp/tmp.XjIOe9NFom
rmpio.sh[40665]: Backup file for /etc/multipath.conf was created in /tmp/tmp.XjIOe9NFom/multipath.conf_2024-07-25_02:08:40
rmpio.sh[40665]: flushed buffers for /dev/dm-7
```

Подтверждение выполененых действий:
```shell
[root@simple-host ~]# diff /etc/multipath.conf /tmp/tmp.XjIOe9NFom/multipath.conf_2024-07-25_02:08:40 
12a13,16
>     multipath {
>                wwid  3624a93705598f4dec0624d4e000113f1
>                alias DATA07-LUN22
>                }


[root@simple-host ~]# multipath -ll | grep -i dm- | awk '{print $1 " " $2}' | sort -k1,1
DATA01-LUN22 (3624a93708618258ed4c4d30a00011493)
DATA02-LUN22 (3624a93708618258ed4c4d30a00011494)
DATA03-LUN22 (3624a93708618258ed4c4d30a00011492)
DATA04-LUN22 (3624a93708618258ed4c4d30a00011491)
DATA08-LUN22 (3624a93705598f4dec0624d4e000113f2)
DATA09-LUN22 (3624a93705598f4dec0624d4e000113f3)
```


## Удаление используемого устройства

Текущее состояние конфигурации в памяти:
```shell
[root@simple-host ~]# multipath -ll | grep -i dm- | awk '{print $1 " " $2}' | sort -k1,1
DATA01-LUN22 (3624a93708618258ed4c4d30a00011493)
DATA02-LUN22 (3624a93708618258ed4c4d30a00011494)
DATA03-LUN22 (3624a93708618258ed4c4d30a00011492)
DATA04-LUN22 (3624a93708618258ed4c4d30a00011491)
DATA08-LUN22 (3624a93705598f4dec0624d4e000113f2)
DATA09-LUN22 (3624a93705598f4dec0624d4e000113f3)
```

Диск используется системой:
```shell
[root@simple-host ~]# df -Th | grep LUN22
/dev/mapper/DATA08-LUN22 xfs       2.0T   33M  2.0T   1% /opt/disk01
```

включение самого высокого уровня логирования (debug):
```shell
export VERBOSE=6
```

попытка удаления мультипас устройства:
```shell
[root@simple-host ~]# ./rmpio.sh --alias DATA08-LUN22
rmpio.sh[44544]: found 'dmsetup' command
rmpio.sh[44544]: found 'multipathd' command
rmpio.sh[44544]: found 'blockdev' command
rmpio.sh[44544]: Module dm_multipath is loaded
rmpio.sh[44544]: systemd service multipathd exists
rmpio.sh[44544]: systemd service multipathd is active
rmpio.sh[44544]: Device wwid: 3624a93705598f4dec0624d4e000113f2
rmpio.sh[44544]: Device alias: DATA08-LUN22
rmpio.sh[44544]: Device dm path: /dev/dm-4
rmpio.sh[44544]: The device 3624a93705598f4dec0624d4e000113f2 (DATA08-LUN22) is multipath device
rmpio.sh[44544]: Error! The device /dev/dm-4 has opened processes:
Name:              DATA08-LUN22
State:             ACTIVE
Read Ahead:        256
Tables present:    LIVE
Open count:        1
Event number:      1
Major, minor:      252, 4
Number of targets: 1
UUID: mpath-3624a93705598f4dec0624d4e000113f2
```

Из конфигурации также ничего не пропадает, убеждаемся в этом:
```shell
[root@simple-host ~]# grep DATA08-LUN22 /etc/multipath.conf
               alias DATA08-LUN22

```

отмонтируем диск:
```shell
[root@simple-host ~]# umount /opt/disk01/
```

Очередная попытка удаления:
```shell
[root@simple-host ~]# ./rmpio.sh --alias DATA08-LUN22
rmpio.sh[46293]: found 'dmsetup' command
rmpio.sh[46293]: found 'multipathd' command
rmpio.sh[46293]: found 'blockdev' command
rmpio.sh[46293]: Module dm_multipath is loaded
rmpio.sh[46293]: systemd service multipathd exists
rmpio.sh[46293]: systemd service multipathd is active
rmpio.sh[46293]: Device wwid: 3624a93705598f4dec0624d4e000113f2
rmpio.sh[46293]: Device alias: DATA08-LUN22
rmpio.sh[46293]: Device dm path: /dev/dm-4
rmpio.sh[46293]: The device 3624a93705598f4dec0624d4e000113f2 (DATA08-LUN22) is multipath device
rmpio.sh[46293]: The device 3624a93705598f4dec0624d4e000113f2 (DATA08-LUN22) not busy
rmpio.sh[46293]: Created directory for backup: /tmp/tmp.OLoHUUml5K
rmpio.sh[46293]: Backup file for /etc/multipath.conf was created in /tmp/tmp.OLoHUUml5K/multipath.conf_2024-07-25_02:15:31
rmpio.sh[46293]: flushed buffers for /dev/dm-4
rmpio.sh[46293]: The next paths were removed: sdp sdl sdh sdd
```

Подтверждение выполененых действий:
```shell
[root@simple-host ~]# diff /etc/multipath.conf /tmp/tmp.OLoHUUml5K/multipath.conf_2024-07-25_02:15:31
13a14,17
>     multipath {
>                wwid  3624a93705598f4dec0624d4e000113f2
>                alias DATA08-LUN22
>                }


[root@simple-host ~]# multipath -ll | grep -i dm- | awk '{print $1 " " $2}' | sort -k1,1
DATA01-LUN22 (3624a93708618258ed4c4d30a00011493)
DATA02-LUN22 (3624a93708618258ed4c4d30a00011494)
DATA03-LUN22 (3624a93708618258ed4c4d30a00011492)
DATA04-LUN22 (3624a93708618258ed4c4d30a00011491)
DATA09-LUN22 (3624a93705598f4dec0624d4e000113f3)
```


## Удаление несуществующего устройства
```shell
[root@simple-host ~]# ./rmpio.sh --alias blablabla
rmpio.sh[47984]: found 'dmsetup' command
rmpio.sh[47984]: found 'multipathd' command
rmpio.sh[47984]: found 'blockdev' command
rmpio.sh[47984]: Module dm_multipath is loaded
rmpio.sh[47984]: systemd service multipathd exists
rmpio.sh[47984]: systemd service multipathd is active
rmpio.sh[47984]: WWID for 'blablabla' not found in multipath configuration
```