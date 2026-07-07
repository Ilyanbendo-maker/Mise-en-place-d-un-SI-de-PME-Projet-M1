-- Base de donnees applicative de Guacamole sur le bastion (MariaDB locale).
-- Le compte applicatif est limite au DML sur sa seule base : pas de DDL,
-- pas de GRANT, connexion restreinte a localhost.

CREATE DATABASE bastioncadavrebd;

CREATE USER 'cadavreadmin'@'localhost' IDENTIFIED BY '[REDACTED]';
GRANT SELECT,INSERT,UPDATE,DELETE ON bastioncadavrebd.* TO 'cadavreadmin'@'localhost';
FLUSH PRIVILEGES;
