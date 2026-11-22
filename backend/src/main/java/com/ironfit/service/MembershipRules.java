package com.ironfit.service;
import com.ironfit.entity.Plan;
import com.ironfit.exception.ApiException;
import java.time.LocalDate;
import java.util.regex.Pattern;
public final class MembershipRules {
 private MembershipRules(){}
 public static boolean infer(Plan p){
  if(p.getDurationUnit()!=null&&p.getDurationCount()!=null&&p.getAccessType()!=null)return true;
  if(p.getDurationUnit()!=null||p.getDurationCount()!=null||p.getAccessType()!=null)return false;
  var m=Pattern.compile("^(\\d+)\\s*(mois|jours?|entrées?|séances?)$",Pattern.CASE_INSENSITIVE).matcher(p.getDuration()==null?"":p.getDuration().trim());
  if(!m.matches())return false;
  int n=Integer.parseInt(m.group(1));String unit=m.group(2).toLowerCase();
  if(!unit.equals("mois")&&!unit.startsWith("jour")&&n!=1)return false;
  p.setDurationCount(n);p.setDurationUnit(unit.equals("mois")?"MONTH":"DAY");
  p.setAccessType(unit.startsWith("entr")||unit.startsWith("séance")?"DAY_PASS":"PERIOD");return true;
 }
 public static void validate(Plan p){
  if(!infer(p)||p.getDurationCount()<1||p.getDurationCount()>3650||!java.util.Set.of("DAY","MONTH").contains(p.getDurationUnit())||!java.util.Set.of("PERIOD","DAY_PASS").contains(p.getAccessType()))throw ApiException.badRequest("Configurez une durée et un type d’accès valides pour cette formule");
  if("DAY_PASS".equals(p.getAccessType())&&(!"DAY".equals(p.getDurationUnit())||p.getDurationCount()!=1))throw ApiException.badRequest("Un pass journée dure un jour");
 }
 public static String snapshot(Plan p){validate(p);return p.getDurationCount()+("MONTH".equals(p.getDurationUnit())?" mois":" jours");}
 public static LocalDate extend(LocalDate from,Plan p,LocalDate today){
  validate(p);LocalDate start=from!=null&&!from.isBefore(today)?from.plusDays(1):today;
  return ("MONTH".equals(p.getDurationUnit())?start.plusMonths(p.getDurationCount()):start.plusDays(p.getDurationCount())).minusDays(1);
 }
}
