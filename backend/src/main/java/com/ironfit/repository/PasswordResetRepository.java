package com.ironfit.repository;

import com.ironfit.entity.PasswordReset;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PasswordResetRepository extends JpaRepository<PasswordReset, Long> {
    Optional<PasswordReset> findByUserId(Long userId);
}
