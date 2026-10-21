package com.ironfit.controller;

import com.ironfit.dto.CatalogDtos.*;
import com.ironfit.dto.CommonDtos.IdResponse;
import com.ironfit.dto.CommonDtos.OkResponse;
import com.ironfit.security.CurrentUser;
import com.ironfit.service.CatalogService;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

/**
 * Tarifs, promotions, boutique : lecture pour tous, écriture admin.
 * Matériel : admin et coachs. Annonces : lecture pour tous, écriture admin et coachs (un coach : les siennes).
 */
@RestController
@RequestMapping("/api")
public class CatalogController {
    private final CatalogService catalog;

    public CatalogController(CatalogService catalog) { this.catalog = catalog; }

    // ---------- Tarifs ----------
    @GetMapping("/plans")
    public List<PlanDto> plans(@RequestParam(required = false) String q, @RequestParam(required = false) Integer limit, @RequestParam(required = false) Integer offset) {
        return catalog.plans(q, limit, offset);
    }

    @PostMapping("/plans")
    @PreAuthorize("hasRole('ADMIN')")
    @ResponseStatus(HttpStatus.CREATED)
    public IdResponse createPlan(@Valid @RequestBody PlanRequest body) { return catalog.createPlan(body); }

    @PutMapping("/plans/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public OkResponse updatePlan(@PathVariable Long id, @Valid @RequestBody PlanRequest body) { catalog.updatePlan(id, body); return OkResponse.OK; }

    @DeleteMapping("/plans/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public OkResponse deletePlan(@PathVariable Long id) { catalog.deletePlan(id); return OkResponse.OK; }

    // ---------- Promotions ----------
    @GetMapping("/promos")
    public List<PromoDto> promos(@RequestParam(required = false) String q, @RequestParam(required = false) Integer limit, @RequestParam(required = false) Integer offset) {
        return catalog.promos(q, limit, offset);
    }

    @PostMapping("/promos")
    @PreAuthorize("hasRole('ADMIN')")
    @ResponseStatus(HttpStatus.CREATED)
    public IdResponse createPromo(@Valid @RequestBody PromoRequest body) { return catalog.createPromo(body); }

    @PutMapping("/promos/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public OkResponse updatePromo(@PathVariable Long id, @Valid @RequestBody PromoRequest body) { catalog.updatePromo(id, body); return OkResponse.OK; }

    @DeleteMapping("/promos/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public OkResponse deletePromo(@PathVariable Long id) { catalog.deletePromo(id); return OkResponse.OK; }

    // ---------- Boutique ----------
    @GetMapping("/products")
    public List<ProductDto> products(@RequestParam(required = false) String q, @RequestParam(required = false) Integer limit, @RequestParam(required = false) Integer offset) {
        return catalog.products(q, limit, offset);
    }

    @PostMapping("/products")
    @PreAuthorize("hasRole('ADMIN')")
    @ResponseStatus(HttpStatus.CREATED)
    public IdResponse createProduct(@Valid @RequestBody ProductRequest body) { return catalog.createProduct(body); }

    @PutMapping("/products/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public OkResponse updateProduct(@PathVariable Long id, @Valid @RequestBody ProductRequest body) { catalog.updateProduct(id, body); return OkResponse.OK; }

    @DeleteMapping("/products/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public OkResponse deleteProduct(@PathVariable Long id) { catalog.deleteProduct(id); return OkResponse.OK; }

    // ---------- Matériel ----------
    @GetMapping("/equipment")
    @PreAuthorize("hasAnyRole('ADMIN','COACH')")
    public List<EquipmentDto> equipment(@RequestParam(required = false) String q, @RequestParam(required = false) Integer limit, @RequestParam(required = false) Integer offset) {
        return catalog.equipment(q, limit, offset);
    }

    @PostMapping("/equipment")
    @PreAuthorize("hasAnyRole('ADMIN','COACH')")
    @ResponseStatus(HttpStatus.CREATED)
    public IdResponse createEquipment(@Valid @RequestBody EquipmentRequest body) { return catalog.createEquipment(body); }

    @PutMapping("/equipment/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','COACH')")
    public OkResponse updateEquipment(@PathVariable Long id, @Valid @RequestBody EquipmentRequest body) { catalog.updateEquipment(id, body); return OkResponse.OK; }

    @DeleteMapping("/equipment/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','COACH')")
    public OkResponse deleteEquipment(@PathVariable Long id) { catalog.deleteEquipment(id); return OkResponse.OK; }

    // ---------- Annonces ----------
    @GetMapping("/announcements")
    public List<AnnouncementDto> announcements(@RequestParam(required = false) String q, @RequestParam(required = false) Integer limit, @RequestParam(required = false) Integer offset) {
        return catalog.announcements(q, limit, offset);
    }

    @PostMapping("/announcements")
    @PreAuthorize("hasAnyRole('ADMIN','COACH')")
    @ResponseStatus(HttpStatus.CREATED)
    public IdResponse createAnnouncement(@AuthenticationPrincipal CurrentUser me, @Valid @RequestBody AnnouncementRequest body) {
        return catalog.createAnnouncement(me, body);
    }

    @PutMapping("/announcements/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','COACH')")
    public OkResponse updateAnnouncement(@AuthenticationPrincipal CurrentUser me, @PathVariable Long id, @Valid @RequestBody AnnouncementRequest body) {
        catalog.updateAnnouncement(me, id, body);
        return OkResponse.OK;
    }

    @DeleteMapping("/announcements/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','COACH')")
    public OkResponse deleteAnnouncement(@AuthenticationPrincipal CurrentUser me, @PathVariable Long id) {
        catalog.deleteAnnouncement(me, id);
        return OkResponse.OK;
    }
}
