# syntax=docker/dockerfile:1

ARG PYTHON_VERSION=3.11.5
FROM python:${PYTHON_VERSION}-slim AS base

# Prevent Python from writing .pyc files and enable unbuffered output
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV FLASK_DEBUG=1

# Install required packages (Apache, mod_wsgi, and dependencies)
RUN apt-get update && apt-get install -y \
    apache2 \
    libapache2-mod-wsgi-py3 \
    unixodbc \
    unixodbc-dev \
    && apt-get clean

# Install Microsoft ODBC Driver 18 for SQL Server
RUN apt-get update && apt-get install -y \
    curl \
    gpg \
    lsb-release \
    apt-transport-https \
    ca-certificates

# Add Microsoft GPG key
RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /etc/apt/keyrings/microsoft.gpg

# Add Microsoft repository for ODBC Driver 18
RUN echo "deb [arch=arm64 signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/debian/12/prod bookworm main" | tee /etc/apt/sources.list.d/mssql-release.list

# Update package lists and install ODBC Driver 18
RUN apt-get update && ACCEPT_EULA=Y apt-get install -y msodbcsql18 \
    && apt-get clean


# Set the working directory
WORKDIR /var/www/userStudy

# Copy application files and Apache configuration
COPY . /var/www/userStudy
COPY userStudy.conf /etc/apache2/sites-available/userStudy.conf
RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Set correct permissions for Apache
RUN chown -R www-data:www-data /var/www/userStudy
RUN chmod -R 755 /var/www/userStudy

# Enable WSGI, disable default conf and enable our conf
RUN a2enmod wsgi
RUN a2ensite userStudy.conf 
RUN a2dissite 000-default.conf

# Expose the port that the application listens on.
EXPOSE 80

# Start Apache in foreground
CMD ["apachectl", "-D", "FOREGROUND"]