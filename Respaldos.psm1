function Remove-CloneFolder {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Source,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Destination
    )

    begin { # Funciones Auxiliares, solo se definen una vez
        function Test-RobocopySuccess {
            param([int]$ExitCode)
            # Robocopy usa códigos de salida especiales.
            # 0 a 7 normalmente se consideran éxito.
            return ($ExitCode -lt 8)
        }
    }

    process {
	    $sourceRoot      = [System.IO.Path]::GetFullPath($Source).TrimEnd('\')      + '\'
        $destinationRoot = [System.IO.Path]::GetFullPath($Destination).TrimEnd('\') + '\'
        

        Write-Host "SOURCE      = [$sourceRoot]"
        Write-Host "DESTINATION = [$destinationRoot]"

        $eq       = ($sourceRoot.Equals($destinationRoot,     [System.StringComparison]::OrdinalIgnoreCase))
        $dest_src = ($destinationRoot.StartsWith($sourceRoot, [System.StringComparison]::OrdinalIgnoreCase))
        $src_dest = ($sourceRoot.StartsWith($destinationRoot, [System.StringComparison]::OrdinalIgnoreCase))
        $source_exists = -not (Test-Path -LiteralPath $Source -PathType Container)

            ### Validaciones ###
        Write-Host "Validacion A - $(-not $eq)"
        if ($eq) {
            throw "Misma carpeta de Origen y de Destino."
        }
        
        Write-Host "Validacion B - $(-not $source_exists)"
        if ($source_exists) {
            throw "La carpeta origen no existe: $Source"
        }

	    Write-Host "Validacion C - $(-not $dest_src)"
        if ($dest_src) {
            throw "El destino no puede estar dentro del origen."
        }

        Write-Host "Validacion D - $(-not $src_dest)"
	    if ($src_dest) {
            throw "El origen no puede estar dentro del destino."
        }
            ### Fin Validaciones ###

        if ($PSCmdlet.ShouldProcess($Destination, "Eliminar carpeta $Destination y clonar desde $Source")) {
            try {
                if (Test-Path -LiteralPath $Destination) {
                    Remove-Item -LiteralPath $Destination -Recurse -Force -ErrorAction Stop
                }

                New-Item -ItemType Directory -Path $Destination -Force | Out-Null

                $args = @(
                    $Source
                    $Destination
                    "/E"          # copia subcarpetas, incluidas vacías
                    #"/L"           # solo lista, no realiza operaciones
                    "/COPY:DAT"   # datos, atributos, timestamps
                    "/DCOPY:DAT"  # timestamps de directorios
                    "/R:2"        # 2 reintentos
                    "/MT:16"      # hilos de procesamiento
                    "/W:2"        # espera 2 segundos entre reintentos
                    "/V"          # modo Verboso
                    #"/NFL"         # no lista archivos
                    #"/NDL"         # no lista directorios
                    #"/NP"          # no muestra progreso
                )

                & robocopy @args 2>&1
                $exitCode = $LASTEXITCODE

                # Write-Host "LASTEXITCODE = $LASTEXITCODE"
                if (-not (Test-RobocopySuccess -ExitCode $exitCode)) {
                    throw "Robocopy falló. Código de salida: $exitCode"
                }

                return $true
            }
            catch {
                throw "Error al clonar la carpeta. Detalle: $($_.Exception.Message)"
            }
        }
    }
}
