# Описание функций логирования

- Все функции имеют фасилитет (категорию) **local7**.  
  Он предназначен для логов, специфичных для определенной системы или приложения.

- Для активации данных функций требуется установить несколько переменных вначале скрипта:
  - переменная **$VERBOSE** - устанавливает уровень логирования
  - переменная **$ME** - устанавливается именем скрипта ``` ME=`basename $0` ```  
    для понимания какой скрипт выдал сообщение

- По умолчанию уровень логирования во всех скриптах установлен в **4**
  [список уровней логирования](logging-levels.md)

### Аргументы функций
1) **MESSAGE** - Сообщение. Простой текст с информацией;
2) **FILE_PATH** - Дополнительный, необязательный аргумент, полного пути до файла.  
   Предназначен для дополнительного логирования в файл.


### Уровни логирования:

1) **log_crit** - local7.crit  
    Критические ошибки, говорят о серьезных проблемах, которые могут привести к остановке приложения;

```
function log_crit () {
        [ ${VERBOSE} -lt 1 ] && return
        local MESSAGE="$1"
        local FILE_PATH="$2"

        if [ -f "$FILE_PATH" ]; then echo $MESSAGE >> $FILE_PATH; fi
        local PRI='local7.crit'
        logger -s -p ${PRI} -t ${ME}[$$] -- ${MESSAGE}
}
```

2) **log_error** - local7.error  
    Указывает на ошибки, которые мешают нормальной работе приложения.  
    Ошибки на этом уровне, ведут к полной неработоспособности приложения  
    **Любые ошибки мешающие работе скрипта приостанавливают его работу и вызывают log_error**;  

```
function log_error () {
        [ ${VERBOSE} -lt 2 ] && return
        local MESSAGE="$1"
        local FILE_PATH="$2"

        if [ -f "$FILE_PATH" ]; then echo $MESSAGE >> $FILE_PATH; fi
        local PRI='local7.error'
        logger -s -p ${PRI} -t ${ME}[$$] -- ${MESSAGE}
}
```

3) **log_warning** - local7.warning  
    Указывает на потенциальную проблему, которая не является критической, но может вызывать отклонения в тесте;

```
function log_warning () {
        [ ${VERBOSE} -lt 3 ] && return
        local MESSAGE="$1"
        local FILE_PATH="$2"

        if [ -f "$FILE_PATH" ]; then echo $MESSAGE >> $FILE_PATH; fi
        local PRI='local7.warning'
        logger -s -p ${PRI} -t ${ME}[$$] -- ${MESSAGE}
}
```

4) **log_notice** - local7.notice  
    Уровень для сообщений, которые не являются ошибками, но являются важными  
    **Успешное выполнение скрипта вызывает функцию log_notice**;

```
function log_notice () {
        [ ${VERBOSE} -lt 4 ] && return
        local MESSAGE="$1"
        local FILE_PATH="$2"

        if [ -f "$FILE_PATH" ]; then echo $MESSAGE >> $FILE_PATH; fi
        local PRI='local7.notice'
        logger -s -p ${PRI} -t ${ME}[$$] -- ${MESSAGE}
}
```

5) **log_info** - local7.info  
    Сообщения обычно содержат информацию о нормальных событиях или операциях, которые происходят в при работе приложения;

```
function log_info () {
        [ ${VERBOSE} -lt 5 ] && return
        local MESSAGE="$1"
        local FILE_PATH="$2"

        if [ -f "$FILE_PATH" ]; then echo $MESSAGE >> $FILE_PATH; fi
        local PRI='local7.info'
        logger -s -p ${PRI} -t ${ME}[$$] -- ${MESSAGE}
}
```

6) **log_debug** - local7.debug  
    Наиболее детальный уровень логирования, который включает различные диагностические сообщения, помогающие в отладке;

```
function log_debug () {
        [ ${VERBOSE} -lt 6 ] && return
        local MESSAGE="$1"
        local FILE_PATH="$2"

        if [ -f "$FILE_PATH" ]; then echo $MESSAGE >> $FILE_PATH; fi
        local PRI='local7.debug'
        logger -s -p ${PRI} -t ${ME}[$$] -- ${MESSAGE}
}
```