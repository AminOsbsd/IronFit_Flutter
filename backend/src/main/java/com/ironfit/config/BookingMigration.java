package com.ironfit.config;
import org.springframework.stereotype.Component;
import org.springframework.core.annotation.Order;
import org.springframework.boot.*;
import org.springframework.transaction.annotation.Transactional;
import com.ironfit.repository.*;
import com.ironfit.entity.*;
import java.time.*;
@Component @Order(10)
public class BookingMigration implements ApplicationRunner {
 private final BookingRepository legacy; private final DatedBookingRepository dated;
 public BookingMigration(BookingRepository legacy,DatedBookingRepository dated){this.legacy=legacy;this.dated=dated;}
 @Transactional public void run(ApplicationArguments args){
  LocalDate today=LocalDate.now(ZoneId.of("Africa/Tunis"));
  for(Booking old:legacy.findAll()) if(!Boolean.TRUE.equals(old.getMigrated()) && !dated.existsByLegacyBookingId(old.getId())){
   ClassSession c=old.getClassSession(); LocalDate d=today.plusDays((c.getDay()-today.getDayOfWeek().getValue()+8)%7);
   if(d.equals(today)&&LocalTime.parse(c.getTime()).isBefore(LocalTime.now(ZoneId.of("Africa/Tunis"))))d=d.plusWeeks(1);
   DatedBooking b=new DatedBooking(old.getUser(),c);b.setSessionDate(d);b.setLegacyBookingId(old.getId());dated.save(b);old.setMigrated(true);
  }
 }
}
