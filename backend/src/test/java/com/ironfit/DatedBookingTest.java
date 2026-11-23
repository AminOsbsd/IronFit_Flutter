package com.ironfit;
import org.junit.jupiter.api.Test;
import java.time.*;
import java.util.Map;
import static org.assertj.core.api.Assertions.*;
class DatedBookingTest extends ApiTestSupport {
 @Test void datesHaveIndependentCapacityAndIdempotentBooking()throws Exception {
  var u=users.findById(id("youssef")).orElseThrow();u.setSubEnd(LocalDate.now().plusDays(60));users.save(u);
  var admin=login("admin");var member=login("youssef");var other=login("leila");
  var day=LocalDate.now(ZoneId.of("Africa/Tunis")).plusDays(1);
  var created=post("classes",Map.of("day",day.getDayOfWeek().getValue()-1,"time","18:00","title","Dated test","spots",1),admin);
  long id=created.body().get("id").asLong();
  var first=Map.of("class_id",id,"session_date",day.toString(),"booked",true);
  assertThat(post("book",first,member).status()).isEqualTo(200);
  assertThat(post("book",first,member).body().get("booked").asBoolean()).isTrue();
  assertThat(post("book",first,other).status()).isEqualTo(409);
  assertThat(post("book",Map.of("class_id",id,"session_date",day.plusWeeks(1).toString(),"booked",true),member).status()).isEqualTo(200);
  assertThat(post("book",Map.of("class_id",id,"session_date",day.toString(),"booked",false),member).status()).isEqualTo(200);
  assertThat(get("classes/"+id+"/participants?date="+day,admin).body()).isEmpty();
  assertThat(get("classes/"+id+"/participants?date="+day.plusWeeks(1),admin).body()).hasSize(1);
  assertThat(post("classes/"+id+"/present",Map.of("member_id",id("youssef"),"session_date",day.plusWeeks(1).toString()),admin).status()).isEqualTo(400);
 }
 @Test void bookingMustBeCoveredByMembership()throws Exception {
  var member=login("youssef");var admin=login("admin");var user=users.findById(id("youssef")).orElseThrow();user.setSubEnd(LocalDate.now().plusDays(1));users.save(user);
  var date=LocalDate.now().plusDays(14);long id=post("classes",Map.of("day",date.getDayOfWeek().getValue()-1,"time","18:00","title","Beyond expiry","spots",4),admin).body().get("id").asLong();
  assertThat(post("book",Map.of("class_id",id,"session_date",date.toString(),"booked",true),member).status()).isEqualTo(403);
 }
 @org.springframework.beans.factory.annotation.Autowired com.ironfit.repository.BookingRepository legacy;
 @org.springframework.beans.factory.annotation.Autowired com.ironfit.repository.DatedBookingRepository dated;
 @org.springframework.beans.factory.annotation.Autowired com.ironfit.repository.ClassSessionRepository classRows;
 @org.springframework.beans.factory.annotation.Autowired com.ironfit.config.BookingMigration migration;
 @Test void canceledMigratedReservationDoesNotReturnOnRestart(){
  var old=new com.ironfit.entity.Booking(users.findById(id("amira")).orElseThrow(),classRows.findAll().get(0));legacy.save(old);
  migration.run(null);
  var copied=dated.findAll().stream().filter(b->old.getId().equals(b.getLegacyBookingId())).findFirst().orElseThrow();
  dated.deleteById(copied.getId());migration.run(null);
  assertThat(dated.existsByLegacyBookingId(old.getId())).isFalse();assertThat(legacy.findById(old.getId()).orElseThrow().getMigrated()).isTrue();
 }
 @Test void explicitMembershipFieldsGenerateDisplayDuration()throws Exception {
  var admin=login("admin");var result=post("plans",Map.of("name","Structured","price",30,"duration_unit","DAY","duration_count",15,"access_type","PERIOD"),admin);
  assertThat(result.status()).isEqualTo(201);
  assertThat(post("plans",Map.of("name","Invalid pass","price",30,"duration_unit","MONTH","duration_count",1,"access_type","DAY_PASS"),admin).status()).isEqualTo(400);
 }
 @org.springframework.beans.factory.annotation.Autowired com.ironfit.repository.CheckinRepository checkins;
 @Test void attendanceCanBeReviewedAfterClassAndCorrectedWithoutDuplicates()throws Exception {
  var coach=login("sami");var member=login("youssef");var other=login("leila");
  var day=LocalDate.now(ZoneId.of("Africa/Tunis")).minusDays(1);
  long classId=post("classes",Map.of("day",day.getDayOfWeek().getValue()-1,"time","18:00","title","Attendance review"),coach).body().get("id").asLong();
  var booking=new com.ironfit.entity.DatedBooking(users.findById(id("youssef")).orElseThrow(),classRows.findById(classId).orElseThrow());booking.setSessionDate(day);dated.save(booking);
  var url="classes/"+classId+"/present";
  var present=Map.of("member_id",id("youssef"),"session_date",day.toString(),"attendance_status","present");
  assertThat(post(url,present,member).status()).isEqualTo(403);
  assertThat(post(url,present,other).status()).isEqualTo(403);
  long before=checkins.count();
  assertThat(post(url,present,coach).status()).isEqualTo(200);
  assertThat(post(url,present,coach).status()).isEqualTo(200);
  assertThat(checkins.count()).isEqualTo(before+1);
  var rows=get("classes?week="+day,member).body();
  var row=java.util.stream.StreamSupport.stream(rows.spliterator(),false).filter(x->x.path("id").asLong()==classId).findFirst().orElseThrow();
  assertThat(row.path("attendance_status").asText()).isEqualTo("present");
  assertThat(post(url,Map.of("member_id",id("youssef"),"session_date",day.toString(),"attendance_status","absent"),coach).status()).isEqualTo(200);
  assertThat(checkins.count()).isEqualTo(before);
  assertThat(get("classes/"+classId+"/participants?date="+day,coach).body().get(0).path("attendance_status").asText()).isEqualTo("absent");
  assertThat(post(url,present,coach).status()).isEqualTo(200);
  assertThat(checkins.count()).isEqualTo(before+1);
  assertThat(post(url,Map.of("member_id",id("youssef"),"session_date",day.toString(),"attendance_status","invalid"),coach).status()).isEqualTo(400);
 }
}
