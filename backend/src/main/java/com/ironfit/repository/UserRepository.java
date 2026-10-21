package com.ironfit.repository;

import com.ironfit.entity.Role;
import com.ironfit.entity.User;
import java.time.LocalDate;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface UserRepository extends JpaRepository<User, Long> {

    @Query("select u from User u where lower(u.login) = lower(:id) or lower(u.email) = lower(:id)")
    Optional<User> findByLoginOrEmail(@Param("id") String loginOrEmail);

    Optional<User> findByEmailIgnoreCase(String email);

    boolean existsByLoginIgnoreCase(String login);

    boolean existsByEmailIgnoreCase(String email);

    boolean existsByLoginIgnoreCaseAndIdNot(String login, Long id);

    boolean existsByEmailIgnoreCaseAndIdNot(String email, Long id);

    @Query("select u from User u where u.id = :id and u.role in :roles")
    Optional<User> findByIdAndRoleIn(@Param("id") Long id, @Param("roles") Collection<Role> roles);

    /**
     * Recherche de membres/coachs. {@code coachId} non nul : uniquement les clients actifs de ce coach.
     * {@code q} est un motif LIKE déjà en minuscules (ou null).
     */
    @Query("""
            select u from User u left join fetch u.plan
            where u.role in :roles
              and (:role is null or u.role = :role)
              and (:active is null or u.active = :active)
              and (:q is null or lower(u.name) like :q or lower(u.login) like :q or lower(u.email) like :q or lower(coalesce(u.phone, '')) like :q)
              and (:coachId is null or exists (select 1 from CoachClient cc where cc.client = u and cc.coach.id = :coachId and cc.status = 'active'))
            order by lower(u.name)""")
    List<User> search(@Param("roles") Collection<Role> roles, @Param("role") Role role, @Param("active") Boolean active,
                      @Param("q") String q, @Param("coachId") Long coachId, Pageable page);

    List<User> findByRoleAndActiveTrueOrderByNameAsc(Role role);

    List<User> findByRoleInAndActiveTrueAndIdNot(Collection<Role> roles, Long excludedId);

    long countByRoleIn(Collection<Role> roles);

    long countByRole(Role role);

    long countByRoleInAndSubEndGreaterThanEqual(Collection<Role> roles, LocalDate date);

    long countByRoleInAndActiveFalse(Collection<Role> roles);

    @Query("select count(u) from User u where u.role = com.ironfit.entity.Role.ATHLETE and (u.subEnd is null or u.subEnd < :today)")
    long countAthletesWithoutSubscription(@Param("today") LocalDate today);

    @Query("select u from User u where u.role in :roles and u.subEnd between :from and :to order by u.subEnd")
    List<User> findExpiring(@Param("roles") Collection<Role> roles, @Param("from") LocalDate from, @Param("to") LocalDate to);

    @Query("select u from User u where u.role in :roles and u.subEnd < :today order by u.subEnd desc")
    List<User> findLapsed(@Param("roles") Collection<Role> roles, @Param("today") LocalDate today, Pageable page);

    @Query("select u from User u where u.id in :ids and u.subEnd between :from and :to order by u.subEnd")
    List<User> findExpiringAmong(@Param("ids") Collection<Long> ids, @Param("from") LocalDate from, @Param("to") LocalDate to);
}
