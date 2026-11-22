package com.ironfit.entity;
import jakarta.persistence.*;
import lombok.*;
@Embeddable @Getter @Setter @NoArgsConstructor
public class WorkoutSet {
 private Long exerciseId;
 @Column(length=120) private String exerciseName;
 private Integer setNumber;
 private Integer reps;
 @Column(precision=8,scale=2) private java.math.BigDecimal weight;
}
