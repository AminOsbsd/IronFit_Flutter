package com.ironfit.config;

import org.hibernate.dialect.DatabaseVersion;
import org.hibernate.dialect.MariaDBDialect;

/**
 * Dialecte par défaut pour le MySQL de XAMPP, qui est en réalité MariaDB 10.4.
 * Via le pilote MySQL Connector/J, MariaDB se présente comme « 5.5.5-10.4.x-MariaDB » : Hibernate lirait la version 5.5.5.
 * On fixe donc la version minimale réelle (10.4). Pour un vrai serveur MySQL 8+, utiliser DB_DIALECT=org.hibernate.dialect.MySQLDialect.
 */
public class XamppMariaDbDialect extends MariaDBDialect {
    public XamppMariaDbDialect() {
        super(DatabaseVersion.make(10, 4));
    }
}
