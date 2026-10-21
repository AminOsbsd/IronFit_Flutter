package com.ironfit.dto;

import com.ironfit.entity.Announcement;
import com.ironfit.entity.Equipment;
import com.ironfit.entity.Plan;
import com.ironfit.entity.Product;
import com.ironfit.entity.Promo;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;
import java.time.LocalDate;

/** Tarifs, promotions, boutique, matériel et annonces. */
public final class CatalogDtos {
    private CatalogDtos() {}

    public record PlanDto(Long id, String name, BigDecimal price, String duration, String descr) {
        public static PlanDto of(Plan p) { return new PlanDto(p.getId(), p.getName(), p.getPrice(), p.getDuration(), p.getDescr()); }
    }

    public record PlanRequest(
            @NotBlank(message = "Champ obligatoire : Nom") @Size(max = 120, message = "Nom trop long") String name,
            @NotNull(message = "Champ obligatoire : Prix") @PositiveOrZero(message = "Valeur invalide : Prix") BigDecimal price,
            @Size(max = 60, message = "Durée trop longue") String duration,
            @Size(max = 2000, message = "Description trop longue") String descr) {}

    public record PromoDto(Long id, String title, String descr, Integer discount, LocalDate until) {
        public static PromoDto of(Promo p) { return new PromoDto(p.getId(), p.getTitle(), p.getDescr(), p.getDiscount(), p.getUntil()); }
    }

    public record PromoRequest(
            @NotBlank(message = "Champ obligatoire : Titre") @Size(max = 160, message = "Titre trop long") String title,
            @Size(max = 2000, message = "Description trop longue") String descr,
            @Min(value = 0, message = "Valeur invalide : Réduction") @Max(value = 100, message = "Valeur invalide : Réduction") Integer discount,
            LocalDate until) {}

    public record ProductDto(Long id, String name, String category, BigDecimal price, Integer stock) {
        public static ProductDto of(Product p) { return new ProductDto(p.getId(), p.getName(), p.getCategory(), p.getPrice(), p.getStock()); }
    }

    public record ProductRequest(
            @NotBlank(message = "Champ obligatoire : Produit") @Size(max = 120, message = "Nom trop long") String name,
            @Size(max = 60, message = "Catégorie trop longue") String category,
            @NotNull(message = "Champ obligatoire : Prix") @PositiveOrZero(message = "Valeur invalide : Prix") BigDecimal price,
            @PositiveOrZero(message = "Valeur invalide : Stock") Integer stock) {}

    public record EquipmentDto(Long id, String name, String category, Integer qty, String status) {
        public static EquipmentDto of(Equipment e) { return new EquipmentDto(e.getId(), e.getName(), e.getCategory(), e.getQty(), e.getStatus()); }
    }

    public record EquipmentRequest(
            @NotBlank(message = "Champ obligatoire : Nom") @Size(max = 120, message = "Nom trop long") String name,
            @Size(max = 60, message = "Catégorie trop longue") String category,
            @PositiveOrZero(message = "Valeur invalide : Quantité") Integer qty,
            @Pattern(regexp = "^(OK|Maintenance|Hors service)?$", message = "État invalide") String status) {}

    public record AnnouncementDto(Long id, String title, String body, LocalDate postedOn, Long authorId, String authorName) {
        public static AnnouncementDto of(Announcement a) {
            return new AnnouncementDto(a.getId(), a.getTitle(), a.getBody(), a.getPostedOn(), a.authorId(), a.getAuthor() == null ? null : a.getAuthor().getName());
        }
    }

    public record AnnouncementRequest(
            @NotBlank(message = "Champ obligatoire : Titre") @Size(max = 160, message = "Titre trop long") String title,
            @Size(max = 2000, message = "Message trop long") String body,
            LocalDate postedOn) {}
}
