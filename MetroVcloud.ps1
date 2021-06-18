########################## REQUISITOS #################################
# 
# 1 - Se correr con el script apuntando a un archivo csv como en el ejemplo de mas abajo. 
#
# 2 - El mismo tiene que tener la siguiente estructura para funcionar:
#
# grupotest,name
# 1,Centrix0024 (2d3dc961-3203-4481-8635-53268de609f5)
# 1,Centrix0026 (280c322b-a756-4ebf-ae70-f6235572e8e2)
# 2,Centrix0025 (2d3dc961-3203-4481-8635-53268de609f4)
# 2,Centrix0028 (280c322b-a756-4ebf-ae70-f6235572e8ed)
#
#
# El grupo indica las VM's que se ejecutaran por hora en el script.
# Siendo 1 las vms que se ejecuran en la primera hora
# el 2 las Vms que se ejecutaran luego de la primera hora
# el 3 las Vms que se ejecutaran luego de la segunda hora, etc
#
# 3 - El nombre de las VM's del archivo, tiene que ser de la manera en la que se ven en Vcenter
# Como se muestra en el punto 2 (dos). 
# El Script no va a funcionar con los nombres con se ven en vcloud.
#
# 4 - El numero de grupos por defecto es 1, para correr mas de un grupo tal cual se indica en el punto 2 (dos)
# se debe ejecutar "-cantidad_grupos" con la cantidad de grupos como se muestra en los ejemplos
# En el ejemplo se muestra para hacer 2 (dos) grupos
#
# 5 - Debe existir una carpeta para los Logs
#
################################
#
# Aclaraciones: 
#
# 1- El parametro "-LogPath" no es mandatorio, indica una carpeta de logs (que debe debe existir, no se crea sola)
# si no lo lo indicamos por defecto asume que la carpeta de logs se encuentra en "c:\logs"
#
# 2- La VMs migradas se encenderan solo si estaban encendidas antes de ser migradas
#
################################



############# EJEMPLOS #############

####  DESDE CMD o Script .bat  EJEMPLO ####
#
#Para realizar migracion de VM's
#powershell -command "& {C:\Scripts\MetroVcloud.ps1 -csvfile C:\centrix\grupo1.csv }"
#
#Para realizar migracion de VM's y setear mas grupos y ruta diferente de logs (USO COMPLETO)
#powershell -command "& {C:\Scripts\MetroVcloud.ps1 -cantidad_grupos 2 -csvfile C:\centrix\grupo1.csv -LogPath C:\Logs\ }"
#


####  DESDE POWERSHELL EJEMPLO ####
#
#Para realizar migracion de VM's
#.\MetroVcloud.ps1 -csvfile C:\centrix\grupo1.csv
#
#Para realizar migracion de VM's y setear mas grupos y ruta diferente de logs (USO COMPLETO)
#.\MetroVcloud.ps1 -cantidad_grupos 2 -csvfile C:\centrix\grupo1.csv -LogPath C:\Logs\
#


Param(
    [Parameter(Mandatory=$true)]$csvfile,
    $LogPath="C:\Logs\",
    $cantidad_grupos="1"
)


#Cambia cantidad de grupos para Foreach
if($cantidad_grupos -gt "1" ) {
    $cantidad_grupos = 1..$cantidad_grupos
}


#Obtenemos la fecha para usarla en el nombre del reporte luego
$date = Get-Date -format "yyyy-MM-dd_HH_mm"

#Funcion para escribir logs
Function LogWrite
{
   Param ([string]$logstring,
   [string]$Logfile
   )
   

   Add-content $LogPath$Logfile -value $logstring
}


LogWrite -logstring $date": ========= ------- Comienza a trabajar el script ------- =========" -Logfile general.log



#Comprueba el formato y que exista el archivo
if ( Test-Path $LogPath){
    write-host "La ruta de la carpetas de logs es: $($LogPath)" -ForegroundColor Yellow
}
else {
    LogWrite -logstring $date": La ruta de la carpetas de logs no existe:  $($LogPath)" -Logfile general.log
    write-host $date": La ruta de la carpetas de logs no existe:  $($LogPath)" -ForegroundColor Yellow
    Break
}

#Comprueba el formato y que exista el archivo
if ( Test-Path $csvfile){
    $csv1 = Import-CSV $csvfile
    if ( ($csv1[0].psobject.Properties.Name[0] -eq "grupotest") -and ($csv1[1].psobject.Properties.Name[1] -eq "name") ) {
       write-host "CSV importado correctamente" -ForegroundColor Yellow
    }
    else {
    LogWrite -logstring $date": El formato del archivo esta mal: $csv1" -Logfile general.log
    write-host $date":  El formato del archivo esta mal: $csv1" -ForegroundColor Yellow
    Break
    }

}
else {
    LogWrite -logstring $date": La ruta del archivo no existe: $csv1" -Logfile general.log
    write-host $date": La ruta del archivo no existe: $csv1" -ForegroundColor Yellow
    Break
}

write-host "Conectando a Vcenter" -ForegroundColor Yellow
#Conexion a Vcenter
try {
        Connect-VIServer srv-vcenter-01 -ErrorAction stop
}
catch {
    LogWrite -logstring $date": Error Conectando a Vcenter" -Logfile general.log
    write-host $date": Error Conectando a Vcenter" -ForegroundColor Yellow
    Break
}

#>

#Cantidad de Sub-Grupos
$cantidad_grupos | ForEach-Object {

#Seteamos la espera, para que solo se ejecuten las VM's de un grupo por hora
$espera = (get-date).AddHours(1)

$grupo = $_
    Write-Host "Empezando con el grupo: $($grupo)" -ForegroundColor Green
    LogWrite -logstring $date": Empezando con el grupo: $($grupo)" -Logfile general.log
    $csv1.ForEach( {
        $vmName = $($_.name)

        if( $_.grupotest -eq $grupo){
            Write-Host "VM: $vmName" -ForegroundColor Cyan
            

            #Obtiene la VM
            try {
            $vm = Get-VM -Name $vmName -ErrorAction stop
            }
            catch {
                LogWrite -logstring $date": Error Obteniendo la VM: $vmName" -Logfile general.log
                write-host $date": Error Obteniendo la VM: $vmName" -ForegroundColor Yellow
                Break
            }

            #Detenemos unos segundos
            Start-Sleep 1

            #Le damos el nombre sin los espacios
            $nombre_nuevo = $vmName.Split(' ')[0]
            $nombre_nuevo
            $vmEncendida = "0"



            #Comprobamos si esta encendida
            if ($vm.PowerState -eq "PoweredOn") {
                $vmEncendida = "1"                           
                #Apagamos la VM
                try {
                    $vm | Shutdown-VMGuest -Confirm:$false -ErrorAction stop
                }
                catch {
                    LogWrite -logstring $date": Error Apagando la VM: $vmName" -Logfile general.log
                    write-host $date": Error Apgando la VM": $vmName -ForegroundColor Yellow
                    Break
                }
                write-host "Apagando la VM": $vmName -ForegroundColor Yellow

            #Detenemos unos segundos
            Start-Sleep 10

            }

            #Mostramos por Pantalla
            write-host "Removiendo el cloud uuid" -ForegroundColor Cyan
            LogWrite -logstring $date": Removiendo el cloud uuid" -Logfile general.log


            #Remueve cloud uuid
            try {
                (Get-AdvancedSetting -entity $vm -Name cloud.uuid) | Remove-AdvancedSetting -Confirm:$false -ErrorAction stop
            }
            catch {
                LogWrite -logstring $date": Error removiendo cloud uuid: $vmName" -Logfile general.log
                write-host $date": Error removiendo cloud uuid: $vmName" -ForegroundColor Yellow
                Break
            }

            #Detenemos unos segundos
            Start-Sleep 1

            #Mostramos por Pantalla
            write-host "Removiendo limites de la VM" -ForegroundColor Cyan
            LogWrite -logstring $date": Removiendo limites de la VM" -Logfile general.log

            #Realiza des-seteo de limites y reservas
            try {
                $vm | Get-VMResourceConfiguration | set-vmresourceconfiguration -CpuReservationMhz 0 -MemReservationMB 0 -memlimitmb $null -CpuLimitMhz $null -Confirm:$false -ErrorAction stop
            }
            catch {
                LogWrite -logstring $date": Error removiendo limites y reservas: $vmName" -Logfile general.log
                write-host $date": Error removiendo limites y reservas: $vmName" -ForegroundColor Yellow
                Break
            }

            #Detenemos unos segundos
            Start-Sleep 2

            #Obtiene el path del vmx
            try {
                $vmx = Get-VM $vm | Select Name, @{N="VMX";E={$_.Extensiondata.Summary.Config.VmPathName}} -ErrorAction stop
            }
            catch {
                LogWrite -logstring $date": Error obteniendo informacion de la VM: $vmName" -Logfile general.log
                write-host $date": Error obteniendo informacion de la VM: $vmName" -ForegroundColor Yellow
                Break
            }
            
            #Detenemos unos segundos
            Start-Sleep 1

            #Mostramos la ruta del vmx por pantalla
            write-host $vmx -ForegroundColor Cyan


            #Obtenemos el resource pool de la vm
            try {
                $rp = Get-ResourcePool -VM $vm -ErrorAction stop
            }
            catch {
                LogWrite -logstring $date": Error obteniendo el resource pool de la VM: $vmName" -Logfile general.log
                write-host $date": Error obteniendo el resource pool de la VM: $vmName" -ForegroundColor Yellow
                Break
            }

            #Detenemos unos segundos
            Start-Sleep 1

            #Mostramos Resource Pool de la VM
            write-host $rp -ForegroundColor Cyan
            LogWrite -logstring $date": Resource Pool Origen $($rp) de la vm $($vmName)" -Logfile general.log

            #Removemos del inventario la VM
            write-host "Removiendo del inventario la VM $($vmName)" -ForegroundColor Cyan
            LogWrite -logstring $date": Removiendo del inventario la VM $($vmName)" -Logfile general.log

            #Eliminamos del inventario a la VM sin eliminarla del disco
            try {
                Remove-VM -VM $vm -DeletePermanently:$false -Confirm:$false -ErrorAction stop
            }
            catch {
                LogWrite -logstring $date": Error eliminando la VM: $vmName" -Logfile general.log
                write-host $date": Error eliminando la VM: $vmName" -ForegroundColor Yellow
                Break
            }

            
            #Detenemos unos segundos
            Start-Sleep 10

            #Removemos del inventario la VM
            write-host "Registrando la VM $($vmName)" -ForegroundColor Cyan
            LogWrite -logstring $date": Registrando la VM $($vmName)" -Logfile general.log

            #Registramos a la nueva VM con un NUEVO NOMBRE desde la ruta del vmx en el resource pool correspondiente
            try {
                New-VM -Name $nombre_nuevo -VMFilePath $vmx.VMX -ResourcePool "Pool_Centrix_Servidores" -Location "Centrix_" -Confirm:$false -ErrorAction stop
            }
            catch {
                LogWrite -logstring $date": Error registrtando la VM: $vmName" -Logfile general.log
                write-host $date": Error registrando la VM: $vmName" -ForegroundColor Yellow
                Break
            }

            #Detenemos unos segundos
            Start-Sleep 10

            #Si la vm estaba encendida la encendemos
            if ($vmEncendida -eq "1") {
                 #Encendemos la VM
                LogWrite -logstring $date": Encendiendo la VM: $vmName" -Logfile general.log
                write-host $date": Encendiendo la VM: $vmName" -ForegroundColor Yellow
                try {
                    Start-VM -VM $nombre_nuevo -ErrorAction stop
                }
                catch {
                    LogWrite -logstring $date": Error encendiendo la VM: $vmName" -Logfile general.log
                    write-host $date": Error encendiendo la VM: $vmName" -ForegroundColor Yellow
                    Break
                }            
            }
            #
            
            #Detenemos unos segundos
            Start-Sleep 1
            write-host $date": Listo VM: $vmName" -ForegroundColor Yellow
            LogWrite -logstring $date": Listo VM: $vmName" -Logfile general.log
            Start-Sleep 9

        }
    })

    write-host "Finalizando con el Grupo $($grupo)" -ForegroundColor Cyan
    LogWrite -logstring $date": Finalizando con el Grupo $($grupo)" -Logfile general.log



    #chequea cantidad de grupos
    if($cantidad_grupos -gt "1" ) {

        
        #Esperamos el horario para hacer el proximo grupo
        if ((($espera) - (get-date)).Minutes -ge 1 ) {
            ($espera) - (get-date) | Start-Sleep
            write-host "Esperando para ejecutar el proximo grupo" -ForegroundColor Cyan
            LogWrite -logstring $date": Esperando para ejecutar el proximo grupo" -Logfile general.log
        }

    }


}


write-host "Tarea Finalizada" -ForegroundColor Yellow
LogWrite -logstring $date": Tarea Finalizada" -Logfile general.log