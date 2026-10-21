package com.ironfit.service;

import com.ironfit.dto.CatalogDtos.*;
import com.ironfit.dto.CommonDtos.IdResponse;
import com.ironfit.security.CurrentUser;
import java.util.List;

/** Tarifs, promotions, boutique (écriture admin) ; matériel (admin et coachs) ; annonces (admin, coach pour les siennes). */
public interface CatalogService {
    List<PlanDto> plans(String q, Integer limit, Integer offset);
    IdResponse createPlan(PlanRequest req);
    void updatePlan(Long id, PlanRequest req);
    void deletePlan(Long id);

    List<PromoDto> promos(String q, Integer limit, Integer offset);
    IdResponse createPromo(PromoRequest req);
    void updatePromo(Long id, PromoRequest req);
    void deletePromo(Long id);

    List<ProductDto> products(String q, Integer limit, Integer offset);
    IdResponse createProduct(ProductRequest req);
    void updateProduct(Long id, ProductRequest req);
    void deleteProduct(Long id);

    List<EquipmentDto> equipment(String q, Integer limit, Integer offset);
    IdResponse createEquipment(EquipmentRequest req);
    void updateEquipment(Long id, EquipmentRequest req);
    void deleteEquipment(Long id);

    List<AnnouncementDto> announcements(String q, Integer limit, Integer offset);
    IdResponse createAnnouncement(CurrentUser me, AnnouncementRequest req);
    void updateAnnouncement(CurrentUser me, Long id, AnnouncementRequest req);
    void deleteAnnouncement(CurrentUser me, Long id);
}
