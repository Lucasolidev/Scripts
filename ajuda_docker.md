# 🐳 Guia Prático e Comandos de Operação do Docker & Docker Compose

Este guia reúne os principais comandos, conceitos e boas práticas para gerenciamento de contêineres, imagens, redes, volumes e orquestração com **Docker** e **Docker Compose**.

---

## 🚀 1. Ciclo de Vida e Operação de Contêineres

* **Listar contêineres em execução:**
  ```bash
  docker ps
  ```

* **Listar TODOS os contêineres (incluindo os parados):**
  ```bash
  docker ps -a
  ```

* **Iniciar um novo contêiner em segundo plano (Modo Detached `-d`):**
  ```bash
  docker run -d --name meu_app -p 8080:80 nginx:latest
  ```

* **Executar um terminal interativo dentro de um contêiner em execução:**
  ```bash
  docker exec -it meu_app /bin/bash
  # ou sh:
  docker exec -it meu_app sh
  ```

* **Ver os logs de um contêiner em tempo real (`-f`):**
  ```bash
  docker logs -f meu_app
  ```

* **Ver o consumo de CPU, Memória e Rede dos contêineres em tempo real:**
  ```bash
  docker stats
  ```

* **Inspecionar detalhes (IP, montagens, variáveis de ambiente) de um contêiner:**
  ```bash
  docker inspect meu_app
  ```

* **Parar, iniciar e reiniciar um contêiner:**
  ```bash
  docker stop meu_app
  docker start meu_app
  docker restart meu_app
  ```

* **Remover um contêiner parado (ou forçar `-f`):**
  ```bash
  docker rm meu_app
  docker rm -f meu_app
  ```

---

## 🖼️ 2. Gerenciamento de Imagens e Limpeza de Disco

* **Listar imagens baixadas localmente:**
  ```bash
  docker images
  ```

* **Baixar uma imagem do Docker Hub sem executar:**
  ```bash
  docker pull ubuntu:24.04
  ```

* **Construir uma imagem a partir de um `Dockerfile` local:**
  ```bash
  docker build -t meu_usuario/meu_app:v1.0 .
  ```

* **Remover uma imagem local:**
  ```bash
  docker rmi nome_da_imagem
  ```

* **Limpar contêineres parados, redes não usadas e imagens sem tag (Dangling):**
  ```bash
  docker system prune
  ```

* **Limpeza total e agressiva de espaço (Contêineres, Imagens sem uso e Volumes soltos):**
  ```bash
  docker system prune -a --volumes
  ```

---

## 💾 3. Gerenciamento de Volumes Persistentes e Redes

### 📂 Volumes (Persistência de Dados)
* **Criar um volume nomeado:**
  ```bash
  docker volume create meu_volume
  ```

* **Listar volumes existentes:**
  ```bash
  docker volume ls
  ```

* **Executar contêiner montando um volume nomeado:**
  ```bash
  docker run -d -v meu_volume:/var/lib/mysql mysql:8.0
  ```

* **Executar contêiner montando uma pasta local do host (Bind Mount):**
  ```bash
  docker run -d -v /var/www/site:/usr/share/nginx/html:ro -p 80:80 nginx
  ```

---

### 🌐 Redes (Comunicação entre Contêineres)
* **Listar redes do Docker:**
  ```bash
  docker network ls
  ```

* **Criar uma rede personalizada do tipo bridge:**
  ```bash
  docker network create minha_rede
  ```

* **Conectar um contêiner existente a uma rede:**
  ```bash
  docker network connect minha_rede meu_app
  ```

---

## 🐙 4. Gerenciamento com Docker Compose (`docker-compose.yml`)

O Docker Compose permite subir pilhas completas de aplicações com múltiplos contêineres usando um único arquivo de configuração.

### 📋 Comandos Essenciais do Docker Compose

* **Subir todos os serviços da pilha em segundo plano:**
  ```bash
  docker compose up -d
  ```

* **Subir recompilando as imagens (`--build`):**
  ```bash
  docker compose up -d --build
  ```

* **Ver o status dos serviços da pilha:**
  ```bash
  docker compose ps
  ```

* **Acompanhar os logs de todos os serviços em tempo real:**
  ```bash
  docker compose logs -f
  # Acompanhar log de um serviço específico:
  docker compose logs -f web
  ```

* **Reiniciar a pilha inteira:**
  ```bash
  docker compose restart
  ```

* **Parar e remover os contêineres e redes da pilha:**
  ```bash
  docker compose down
  ```

* **Parar a pilha removendo também os volumes associados (`-v`):**
  ```bash
  docker compose down -v
  ```

---

## 📄 5. Modelo Prático de `docker-compose.yml` (Nginx + MySQL + WordPress)

```yaml
version: '3.8'

services:
  db:
    image: mysql:8.0
    container_name: wordpress_db
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: SenhaForteRoot123
      MYSQL_DATABASE: wordpress
      MYSQL_USER: wp_user
      MYSQL_PASSWORD: SenhaForteUser123
    volumes:
      - db_data:/var/lib/mysql
    networks:
      - wp_network

  wordpress:
    image: wordpress:latest
    container_name: wordpress_app
    restart: always
    ports:
      - "8080:80"
    environment:
      WORDPRESS_DB_HOST: db:3306
      WORDPRESS_DB_USER: wp_user
      WORDPRESS_DB_PASSWORD: SenhaForteUser123
      WORDPRESS_DB_NAME: wordpress
    volumes:
      - wp_data:/var/www/html
    networks:
      - wp_network
    depends_on:
      - db

volumes:
  db_data:
  wp_data:

networks:
  wp_network:
    driver: bridge
```
