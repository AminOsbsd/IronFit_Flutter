package com.ironfit.entity;

import jakarta.persistence.AttributeConverter;
import jakarta.persistence.Converter;

/** Stocke le rôle en minuscules (admin / coach / athlete), comme dans l'ancienne base. */
@Converter(autoApply = true)
public class RoleConverter implements AttributeConverter<Role, String> {
    @Override
    public String convertToDatabaseColumn(Role role) { return role == null ? null : role.value(); }

    @Override
    public Role convertToEntityAttribute(String v) { return v == null ? null : Role.from(v); }
}
