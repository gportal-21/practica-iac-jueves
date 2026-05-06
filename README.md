# Práctica IaC - Jueves

## Requisitos Previos

- Docker instalado y en ejecución
- Terraform >= 1.0
- AWS CLI configurado con credenciales válidas
- Node.js instalado
- PowerShell (para Windows)

## Instrucciones de Despliegue

### Paso 1: Construir la Imagen Docker de la API-client

Navegar a la carpeta de la API-client:

```bash
cd src/api
```

Construir la imagen Docker:

```bash
docker build -t image-processor-client .
```

### Paso 2: Preparar las Funciones Lambda

#### 2.1 Configurar Crop Lambda

Navegar a la carpeta de crop-lambda:

```bash
cd src\lambda\crop-lambda
```

Ejecutar el script de construcción:

```powershell
./build.ps1
```

#### 2.2 Configurar Upload Lambda

Navegar a la carpeta de upload-lambda:

```bash
cd src\lambda\upload-lambda
```

Instalar las dependencias:

```bash
npm install
```

### Paso 3: Configurar Terraform Workspaces

Navegar a la carpeta de IaC:

```bash
cd ..\..\..\iac\
```

Crear los workspaces para cada entorno (dev, qa, prod):

```bash
terraform workspace new dev
terraform workspace new qa
terraform workspace new prod
```

Seleccionar el workspace dev (Para el test):

```bash
terraform workspace select dev
```

### Paso 4: Planificar la Infraestructura

Ejecutar el plan para verificar la configuración:

```bash
terraform plan
```

Revisar los recursos que serán creados y asegúrate de que todo sea correcto.

### Paso 5: Aplicar la Infraestructura

Crear los recursos en AWS:

```bash
terraform apply
```

Confirmar escribiendo `yes` cuando se solicite.

### Paso 6: Obtener la URL del API Gateway

Una vez aplicada la infraestructura, obtén la URL de invocación del API Gateway:

```bash
terraform output -raw api_invoke_url
```

O visualiza todos los outputs disponibles:

```bash
terraform output
```

**Guarda esta URL**, la necesitarás en el siguiente paso.

### Paso 7: Ejecutar el Contenedor de la API

Navega a la carpeta de la API:

```bash
cd ..\src\api
```

Ejecuta el contenedor Docker reemplazando `<API_GATEWAY_URL>` con la URL obtenida en el paso anterior:

```bash
docker run -p 3000:3000 -e API_GATEWAY_URL=<API_GATEWAY_URL> --name image-client image-processor-client
```

**Ejemplo:**

```bash
docker run -d -p 3000:3000 -e API_GATEWAY_URL=https://abc123xyz.execute-api.us-east-1.amazonaws.com/dev --name image-client image-processor-client
```

---

## Verificación

- La API estará disponible en `http://localhost:3000`
- Usar Postman o Imnsomnia, o ejecutar comando curl en terminal mandando una imagen de ejemplo

  ```bash
  curl -X POST -F "image=@C:\tu\ruta\a\imagen.jpg" http://localhost:3000/upload | ConvertFrom-Json
  ```

- Verifica los logs del contenedor:

  ```bash
  docker logs image-client
  ```

---

## Limpiar Recursos

Para destruir todos los recursos creados en AWS:

```bash
cd ..\..\iac
terraform destroy
```

Para detener y eliminar el contenedor Docker:

```bash
docker stop image-client
docker rm image-client
```

---

## Notas Importantes

- El workspace **dev** está preconfigurado para la práctica
- Los outputs de Terraform incluyen la URL necesaria para conectar la API
- Asegúrate de tener credenciales válidas en AWS antes de ejecutar `terraform apply`
- Los cambios en Terraform se sincronizan automáticamente en el archivo `.tfstate`
