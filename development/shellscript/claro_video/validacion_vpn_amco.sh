#!/bin/bash

########################################################################################################
##                           SHELLSCRIPT CONEXION VPN CLARO VIDEO                                     ##
##                                                                                                    ##
## Descripcion: ShellScript para levantamiento de VPN en servidor Claro Video                         ##
## Autor: Alexis Abraham Araujo Moreno                                                                ##
## OS: Linux                                                                                          ##
## Fecha Ultima Actualizacion: 4/28/21                                                                ##
##                                                                                                    ##
########################################################################################################

HOST=""
PORT=""
USER=""
PASS=""
TRUSTED_CERT=""

RESULTADO_EJECUCION_PING=0
INTENTOS_FALLIDOS_EN_LEVANTAR_VPN=0
MENSAJE_FALLA_CONECTIVIDAD_CERT="Gateway certificate validation failed"
CADENA_OBTENCION_CERT_REGEX="trusted-cert ="

while true; do

    # realiza el ping al host donde reside la API y guarda el codigo del resultado
    ping -c1 -i1 10.20.1.92 >/dev/null 2>&1
    RESULTADO_EJECUCION_PING=$?

    # obtenemos los PIDS de ejecuciones duplicadas del mismo script, con el fin de no tener en ejecucion y al mismo tiempo
    # procesos del mismo shellscript
    PIDS_DE_SCRIPTS_CORRIENDO=($(ps aux | grep -i $$ | awk '{print $2}' | paste -s -d ' '))

    # se matan los procesos duplicados que ejecuten el mismo shellscript
    for PID_SCRIPT_DUPLICADO in $PIDS_DE_SCRIPTS_CORRIENDO
    do
        if [ $PID_SCRIPT_DUPLICADO -ne $$ ]
        then
            OUTPUT_COMMAND=$(kill -SIGKILL ${PID_SCRIPT_DUPLICADO} &)
        fi
    done

    # si el ping falla (nos da un codigo distinto a 0), intenta levantar la VPN
    if [ $RESULTADO_EJECUCION_PING -ne 0 ]
    then
        INTENTOS_FALLIDOS_EN_LEVANTAR_VPN=$(( INTENTOS_FALLIDOS_EN_LEVANTAR_VPN+1 ))
        # si la vpn se encuentra abajo, se matan los procesos existentes de openfortivpn y vuelve
        # nuevamente a levantar la vpn
        DELETE_PIDS_OPENFORTIVPN=$(pkill openfortivpn)

        # Se ejecuta el comando para levantar la VPN    
        RESULT_OPENFORTIVPN=`openfortivpn "${HOST}":"${PORT}" -u "${USER}" -p "${PASS}" --trusted-cert ${TRUSTED_CERT} &`
        
        sleep 5

        # se obtiene el output ERROR del comando ejecutado y se verifica que contenga en el texto el certificado
        CADENA_OUTPUT_OPENFORTIVPN=$(echo "$RESULT_OPENFORTIVPN" | grep "${MENSAJE_FALLA_CONECTIVIDAD_CERT}")
        
        # si en la cadena del output ERROR si se encontraron coincidencias se procede a retomar el certificado obtenido
        # en la cadena, con el fin de ejecutar nuevamente el comando con el certificado obtenido
        if [ ${#CADENA_OUTPUT_OPENFORTIVPN} -gt 0 ]
        then
            RESULT_CERT=$(echo "$RESULT_OPENFORTIVPN" | grep "${CADENA_OBTENCION_CERT_REGEX}")

            while IFS= read -r LINEA; do
                CERTIFICADO=$(grep -oP "[a-zA-Z0-9]{64}" <<< "$LINEA")
            done <<< "${RESULT_CERT}"
            
            if [ ! -z "$CERTIFICADO" ] 
            then
                TRUSTED_CERT=$CERTIFICADO
            fi
        fi
    else
        break
    fi
    
    # despues de tres intentos fallidos para levantar la VPN, se envia correo con la informacion de la notificacion
    # y se finaliza la ejecucion del script
    if [ $INTENTOS_FALLIDOS_EN_LEVANTAR_VPN -ge 3 ]
    then
        HTML_BODY=$(<./correo.html) 
        FECHA_EJECUCION_SCRIPT=$(date)
        HTML_BODY=$(printf "${HTML_BODY}" "${FECHA_EJECUCION_SCRIPT}" "${INTENTOS_FALLIDOS_EN_LEVANTAR_VPN}")
        HTML_BODY=$(sed 's/"/\\"/g' <<< "${HTML_BODY}")

        TO=""
        SUBJECT="Falla de conectividad a VPN Servidor AMCO Claro Video"

        curl -X POST -H 'Content-Type: application/json' -i http://itoc-tools.triara.mexico:8083/notifications/email/html\
            --data '{"from":"root","to":"'"${TO}"'","subject":"'"${SUBJECT}"'","body":"'"${HTML_BODY}"'"}'

        break
    fi

done