package com.ironfit.service.impl;

import com.ironfit.dto.CatalogDtos.*;
import com.ironfit.dto.CommonDtos.IdResponse;
import com.ironfit.entity.Announcement;
import com.ironfit.entity.Equipment;
import com.ironfit.entity.Plan;
import com.ironfit.entity.Product;
import com.ironfit.entity.Promo;
import com.ironfit.exception.ApiException;
import com.ironfit.repository.AnnouncementRepository;
import com.ironfit.repository.EquipmentRepository;
import com.ironfit.repository.OffsetLimit;
import com.ironfit.repository.PlanRepository;
import com.ironfit.repository.ProductRepository;
import com.ironfit.repository.PromoRepository;
import com.ironfit.repository.UserRepository;
import com.ironfit.security.CurrentUser;
import com.ironfit.service.AccessService;
import com.ironfit.service.CatalogService;
import com.ironfit.service.NotificationService;
import com.ironfit.service.Texts;
import java.time.LocalDate;
import java.util.List;
import java.util.Objects;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional
public class CatalogServiceImpl implements CatalogService {
    private static final String NOT_FOUND = "Élément introuvable";
    private final PlanRepository plans;
    private final PromoRepository promos;
    private final ProductRepository products;
    private final EquipmentRepository equipment;
    private final AnnouncementRepository announcements;
    private final UserRepository users;
    private final NotificationService notifications;

    public CatalogServiceImpl(PlanRepository plans, PromoRepository promos, ProductRepository products, EquipmentRepository equipment,
                              AnnouncementRepository announcements, UserRepository users, NotificationService notifications) {
        this.plans = plans;
        this.promos = promos;
        this.products = products;
        this.equipment = equipment;
        this.announcements = announcements;
        this.users = users;
        this.notifications = notifications;
    }

    private static <T> T find(JpaRepository<T, Long> repo, Long id) { return repo.findById(id).orElseThrow(() -> ApiException.notFound(NOT_FOUND)); }

    private static <T> void remove(JpaRepository<T, Long> repo, Long id) { repo.delete(find(repo, id)); }

    // ---------- Tarifs ----------
    @Override
    @Transactional(readOnly = true)
    public List<PlanDto> plans(String q, Integer limit, Integer offset) {
        return plans.search(Texts.like(q), OffsetLimit.of(offset, limit, 500)).stream().map(PlanDto::of).toList();
    }

    private static void apply(Plan p, PlanRequest r) {
        p.setName(r.name().trim());
        p.setPrice(r.price());
        p.setDuration(Texts.clean(r.duration()));
        p.setDescr(Texts.clean(r.descr()));
    }

    @Override
    public IdResponse createPlan(PlanRequest req) { Plan p = new Plan(); apply(p, req); return new IdResponse(plans.save(p).getId()); }

    @Override
    public void updatePlan(Long id, PlanRequest req) { apply(find(plans, id), req); }

    @Override
    public void deletePlan(Long id) { remove(plans, id); }

    // ---------- Promotions ----------
    @Override
    @Transactional(readOnly = true)
    public List<PromoDto> promos(String q, Integer limit, Integer offset) {
        return promos.search(Texts.like(q), OffsetLimit.of(offset, limit, 500)).stream().map(PromoDto::of).toList();
    }

    private static void apply(Promo p, PromoRequest r) {
        p.setTitle(r.title().trim());
        p.setDescr(Texts.clean(r.descr()));
        p.setDiscount(r.discount() == null ? 0 : r.discount());
        p.setUntil(r.until());
    }

    @Override
    public IdResponse createPromo(PromoRequest req) { Promo p = new Promo(); apply(p, req); return new IdResponse(promos.save(p).getId()); }

    @Override
    public void updatePromo(Long id, PromoRequest req) { apply(find(promos, id), req); }

    @Override
    public void deletePromo(Long id) { remove(promos, id); }

    // ---------- Boutique ----------
    @Override
    @Transactional(readOnly = true)
    public List<ProductDto> products(String q, Integer limit, Integer offset) {
        return products.search(Texts.like(q), OffsetLimit.of(offset, limit, 500)).stream().map(ProductDto::of).toList();
    }

    private static void apply(Product p, ProductRequest r) {
        p.setName(r.name().trim());
        p.setCategory(Texts.clean(r.category()));
        p.setPrice(r.price());
        p.setStock(r.stock() == null ? 0 : r.stock());
    }

    @Override
    public IdResponse createProduct(ProductRequest req) { Product p = new Product(); apply(p, req); return new IdResponse(products.save(p).getId()); }

    @Override
    public void updateProduct(Long id, ProductRequest req) { apply(find(products, id), req); }

    @Override
    public void deleteProduct(Long id) { remove(products, id); }

    // ---------- Matériel ----------
    @Override
    @Transactional(readOnly = true)
    public List<EquipmentDto> equipment(String q, Integer limit, Integer offset) {
        return equipment.search(Texts.like(q), OffsetLimit.of(offset, limit, 500)).stream().map(EquipmentDto::of).toList();
    }

    private static void apply(Equipment e, EquipmentRequest r) {
        e.setName(r.name().trim());
        e.setCategory(Texts.clean(r.category()));
        e.setQty(r.qty() == null ? 1 : r.qty());
        e.setStatus(Texts.clean(r.status()) == null ? "OK" : r.status());
    }

    @Override
    public IdResponse createEquipment(EquipmentRequest req) { Equipment e = new Equipment(); apply(e, req); return new IdResponse(equipment.save(e).getId()); }

    @Override
    public void updateEquipment(Long id, EquipmentRequest req) { apply(find(equipment, id), req); }

    @Override
    public void deleteEquipment(Long id) { remove(equipment, id); }

    // ---------- Annonces ----------
    @Override
    @Transactional(readOnly = true)
    public List<AnnouncementDto> announcements(String q, Integer limit, Integer offset) {
        return announcements.search(Texts.like(q), OffsetLimit.of(offset, limit, 500)).stream().map(AnnouncementDto::of).toList();
    }

    private static void apply(Announcement a, AnnouncementRequest r) {
        a.setTitle(r.title().trim());
        a.setBody(Texts.clean(r.body()));
        a.setPostedOn(r.postedOn() == null ? LocalDate.now() : r.postedOn());
    }

    /** Un coach ne modifie ou ne supprime que ses propres annonces. */
    private Announcement owned(CurrentUser me, Long id) {
        AccessService.require(me.isAdmin() || me.isCoach());
        Announcement a = find(announcements, id);
        if (me.isCoach() && !Objects.equals(a.authorId(), me.id())) throw ApiException.forbidden("Vous ne pouvez modifier que vos propres annonces");
        return a;
    }

    @Override
    public IdResponse createAnnouncement(CurrentUser me, AnnouncementRequest req) {
        AccessService.require(me.isAdmin() || me.isCoach());
        Announcement a = new Announcement();
        apply(a, req);
        a.setAuthor(users.getReferenceById(me.id()));
        Long id = announcements.save(a).getId();
        notifications.notifyAllMembers(me.id(), "Annonce : " + a.getTitle(), a.getBody());
        return new IdResponse(id);
    }

    @Override
    public void updateAnnouncement(CurrentUser me, Long id, AnnouncementRequest req) { apply(owned(me, id), req); }

    @Override
    public void deleteAnnouncement(CurrentUser me, Long id) { announcements.delete(owned(me, id)); }
}
