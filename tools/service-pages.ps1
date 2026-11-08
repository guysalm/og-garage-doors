# Service x city landing pages, dot-sourced by build-city-pages.ps1.
#
# Three services per published area: emergency repair, spring repair and
# maintenance. The plain "Garage Door Repair <City>" query already belongs to
# the city page (and to the home page for Venice), so the repair page here
# targets EMERGENCY repair instead - a second page on the same query would
# split it, and Google tends to index one and drop the other.
#
# Every page is written on its own, not swapped from a shared draft. The build
# fails if two pages share a content H2, and the copy is ASCII-only because
# Windows PowerShell 5.1 reads a BOM-less .ps1 as ANSI.
#
# Inline links: [[city]] [[spring]] [[maintenance]] [[emergency]] resolve to
# the right URL for that page's city.
#
# Photos: drop assets/img/svc-<service>-<city>.jpg (under 100KB, roughly 900x600)
# and the next build uses it. Until then the service's fallback photo ships and
# the build prints a note naming the missing file. Set Alt on the page entry
# when the real photo goes in, so the alt describes that photo.

$SERVICES = [ordered]@{
  emergency = @{
    Prefix      = "emergency-garage-door-repair"
    ServiceName = "Emergency Garage Door Repair"
    ServiceType = "Emergency garage door repair"
    LinkLabel   = "Emergency garage door repair"
    NavLabel    = "Emergency Repair"
    FallbackImg = "assets/img/service-off-track-repair.webp"; FallbackW = 660; FallbackH = 300
    FallbackAlt = "Residential garage door hanging off its track, waiting for emergency repair"
  }
  spring = @{
    Prefix      = "garage-door-spring-repair"
    ServiceName = "Garage Door Spring Repair"
    ServiceType = "Garage door spring repair and replacement"
    LinkLabel   = "Garage door spring repair"
    NavLabel    = "Spring Repair"
    FallbackImg = "assets/img/expertise-residential-opener.webp"; FallbackW = 900; FallbackH = 440
    FallbackAlt = "Torsion spring on its shaft above a residential garage door"
  }
  maintenance = @{
    Prefix      = "garage-door-maintenance"
    ServiceName = "Garage Door Maintenance"
    ServiceType = "Garage door maintenance and tune-up"
    LinkLabel   = "Garage door maintenance"
    NavLabel    = "Maintenance"
    FallbackImg = "assets/img/service-tune-up-maintenance.webp"; FallbackW = 660; FallbackH = 300
    FallbackAlt = "Technician servicing garage door hardware with a hand tool during a tune-up"
  }
}

$P = $SITE.phone_display

# keyed "<service>|<city slug>"
$servicePages = @{

# =================================================================== VENICE
"spring|garage-door-repair-venice-fl" = @{
  Title  = "Garage Door Spring Repair Venice FL | Same-Day Springs"
  Desc   = "Broken garage door spring in Venice, FL? High-cycle torsion and extension springs fitted same day, both sides balanced. Senior discount. Call $P."
  H1     = "Garage Door Spring Repair in Venice, FL"
  HeroH2 = "High-Cycle Springs Fitted Same Day on the Island and the Mainland"
  Intro  = @{
    H2 = "Broken spring on a Venice garage door? Leave the door where it is"
    P  = @(
      "A torsion spring that lets go sounds like a gunshot in the garage, and in Venice it usually happens early in the morning, when the first cycle of the day asks a tired spring to lift the full weight of the door. Once it has broken, the door weighs what it actually weighs &ndash; often 150 pounds or more &ndash; and the opener was never built to lift that on its own."
      "Leave the door closed, unplug the opener if it keeps straining, and call us. We keep the spring sizes common to Venice homes on the truck, so on most calls the door is balanced, tested and running again the same day, on Venice Island, in South Venice or anywhere along the Tamiami Trail."
    )
  }
  Blocks = @(
    @{ H2 = "Torsion or extension: which springs Venice garages use"
       P  = @("Most of the homes we see between Venice Ave and Jacaranda Blvd run a torsion system &ndash; one or two springs on a steel shaft above the door. Older and smaller garages still use extension springs that stretch along the horizontal tracks. They fail differently, and we replace them differently.")
       L  = @(
         "<strong>Torsion springs</strong>: wound on the shaft and released as the door rises. We replace both springs even when only one has broken, because the survivor is the same age and close to the same failure point."
         "<strong>Extension springs</strong>: these stretch beside each track and must run with a safety cable through the middle, so a broken spring cannot whip across the garage. If yours have no containment cable, we add one."
         "<strong>High-cycle option</strong>: a standard spring is rated for about 10,000 cycles. A high-cycle spring lasts several times longer on a door that opens four or five times a day."
         "<strong>Balance before we leave</strong>: with the opener disconnected, the door should hold at waist height on its own. We set the tension until it does."
       ) }
    @{ H2 = "Why Venice homeowners should not adjust a spring themselves"
       P  = @(
         "A wound torsion spring stores enough energy to break a wrist or throw a winding bar across the garage. Online videos make it look like a two-bar job; what they do not show is the cone slipping on a worn set screw. In a town with as many retirees as Venice, we would far rather take the call than hear about the accident."
         "We bring the winding bars, the right cones and a second pair of hands when the job needs it, and we show you the broken coil before quoting, so you can see exactly what failed and why."
       ) }
    @{ H2 = "Same-day spring replacement from Venice Island to Laurel Road"
       P  = @(
         "We work both sides of the Intracoastal every day &ndash; the island streets off Venice Ave, the South Venice neighborhoods, and the newer communities out toward Laurel Rd and Jacaranda Blvd. The price is agreed on the driveway before any spring comes off, the senior and veteran discount applies every day of the week, and there is no surcharge for a Saturday or a holiday."
         "Not sure it is a spring? Look at the coil above the door. If there is a two-inch gap in it, it is &ndash; and we can usually fix it today."
       ) }
  )
  Faqs = @(
    ,@("How do I know if my Venice garage door spring is broken?",
       "Look at the spring above the door: a broken torsion spring shows a clear gap in the coils. Other signs are a loud bang from the garage, a door that rises a few inches and stops, an opener that hums without lifting, or cables hanging loose beside the door.")
    ,@("Should both springs be replaced if only one broke?",
       "On a two-spring door, yes. Both were fitted on the same day and have done the same number of cycles, so the second is usually weeks or months behind the first. Replacing the pair keeps the door balanced and saves you a second visit.")
    ,@("Can I keep using my opener with a broken spring?",
       "Please do not. The opener is designed to guide a balanced door, not to lift its full weight. Running it on a broken spring strips the gear, bends the top section and can snap the cables. Unplug it and leave the door closed until we arrive.")
    ,@("Do you fit high-cycle springs in Venice?",
       "Yes. We carry high-cycle torsion springs rated for several times the life of a builder-grade spring. They cost a little more up front and outlast the standard part by years on a door used every day. We quote both so you can choose.")
  )
}

"maintenance|garage-door-repair-venice-fl" = @{
  Title  = "Garage Door Maintenance Venice FL | Tune-Ups & Lubrication"
  Desc   = "Garage door maintenance in Venice, FL: spring, cable and roller checks, lubrication, balance and safety tests. Seasonal homes too. Call $P."
  H1     = "Garage Door Maintenance in Venice, FL"
  HeroH2 = "Tune-Ups That Keep a Venice Door Quiet, Balanced and Safe"
  Intro  = @{
    H2 = "A Venice garage door tune-up before small wear becomes a breakdown"
    P  = @(
      "Most garage doors fail slowly and then all at once. A roller starts to drag, a hinge loosens, the spring loses a little tension each year, and one morning the opener gives up halfway through the cycle. A maintenance visit catches those things while they are still adjustments rather than repairs."
      "Our tune-up covers the whole system &ndash; springs, cables, drums, rollers, hinges, track, opener and safety sensors &ndash; and it is the visit Venice homeowners book most often once they have had one emergency call too many."
    )
  }
  Blocks = @(
    @{ H2 = "What our Venice tune-up checks, adjusts and lubricates"
       P  = @("Every visit follows the same 25-point routine, and we talk you through what we find as we go:")
       L  = @(
         "<strong>Springs and cables</strong>: inspected for gaps, rust and fraying, with tension reset so the door holds its position by hand."
         "<strong>Rollers and hinges</strong>: worn steel rollers flagged, bearings and pivot points lubricated with a garage-door lubricant rather than a household spray."
         "<strong>Track and fixings</strong>: brackets and lag bolts re-tightened, track checked for straightness and clearance."
         "<strong>Opener</strong>: belt or chain tension, travel limits and force settings checked against the manufacturer's range."
         "<strong>Safety reverse</strong>: photo eyes aligned and the door tested against an obstruction, so it reverses the way it should."
         "<strong>Weather seal</strong>: bottom gasket and side seals checked for the gaps that let rain and summer heat in."
       ) }
    @{ H2 = "Seasonal homes in Venice need a different maintenance schedule"
       P  = @(
         "Plenty of Venice homes sit closed for months while the owners are up north. A door that has not moved since April does not age gracefully: lubricant dries out, rollers flat-spot, the opener's backup battery drains and the humidity gets to work on the springs. The first cycle after a long summer is when we see the most failures."
         "If yours is a seasonal home, book the tune-up for the week you get back, or ask us to come before you arrive. We run the door through full cycles, replace a flat opener battery, and tell you about anything that should not wait."
       ) }
    @{ H2 = "Quieter doors on 55+ streets around Venice"
       P  = @(
         "A lot of our maintenance work on the island and in South Venice is about noise. Lubrication helps, but a door that still rattles usually needs sealed nylon rollers in place of worn steel ones, and a chain drive that wakes the house may be ready for a belt-drive opener. We tell you which, and price it before touching anything."
         "Every visit ends with the door running smoothly by hand as well as on the motor, at the price you were quoted, with the senior and veteran discount applied."
       ) }
  )
  Faqs = @(
    ,@("How often should a Venice garage door be serviced?",
       "Once a year suits most homes. A door that opens more than six or seven times a day, or a seasonal home that sits unused for months, does better with a visit every six months.")
    ,@("Can I lubricate my own garage door between visits?",
       "Yes, and it helps. Use a silicone or lithium garage-door lubricant on the hinges, rollers and springs &ndash; not a penetrating household spray, which strips grease and collects dust. Leave spring tension and cables to us.")
    ,@("What happens if the tune-up finds a worn part?",
       "We show it to you and give you the price to replace it. Nothing is replaced without your say-so, and if you would rather wait, we tell you honestly how long it is likely to last.")
    ,@("Is a tune-up worth it on a newer door?",
       "Usually, yes. Builder-grade hardware loosens in its first couple of years as the door settles, and a balance adjustment at that stage protects the opener and the springs for years afterwards.")
  )
}

"emergency|garage-door-repair-venice-fl" = @{
  Title  = "Emergency Garage Door Repair Venice FL | 24/7 Response"
  Desc   = "Emergency garage door repair in Venice, FL. Door stuck open, off track or a snapped cable? 24/7 response, no weekend surcharge. Call $P."
  H1     = "Emergency Garage Door Repair in Venice, FL"
  HeroH2 = "Someone Answering at Night, Weekends and Holidays in Venice"
  Intro  = @{
    H2 = "Garage door stuck open in Venice? What to do until we arrive"
    P  = @(
      "A door that will not close is a security problem as well as a nuisance, and it rarely picks a convenient moment. We answer the phone around the clock, give you an honest arrival time, and most Venice emergency calls see a technician within 60 to 90 minutes."
      "While you wait: keep cars and people out from under the door, do not pull the red emergency release if a spring or cable has broken, and unplug the opener if it keeps trying to run. Then let us do the lifting."
    )
  }
  Blocks = @(
    @{ H2 = "Emergency repairs we handle on the first visit in Venice"
       P  = @("Our trucks are stocked so that the first visit is usually the only one:")
       L  = @(
         "<strong>Door off its track</strong>: rollers reseated, bent track straightened or replaced, and the reason it came off found rather than guessed at."
         "<strong>Snapped or slack cables</strong>: both sides replaced and the drums reset, so the door hangs level again."
         "<strong>Opener failure</strong>: logic boards, gears, drive belts and limit switches repaired, or the motor replaced when the repair is not worth it."
         "<strong>Door hit by a car</strong>: damaged sections secured, track and hinges straightened, and a matching panel ordered if one is beyond repair."
         "<strong>Sensors that stop it closing</strong>: photo eyes cleaned, realigned or replaced, and the safety reverse tested."
         "<strong>Broken springs</strong>: replaced the same day &ndash; see our <a href=""[[spring]]"">garage door spring repair in Venice</a> page for how we do it."
       ) }
    @{ H2 = "No after-hours premium on Venice emergency calls"
       P  = @(
         "We charge the same rate on a Sunday night as on a Tuesday afternoon, and the senior and veteran discount applies to emergency work too. The technician prices the repair on the driveway, before any tool comes out, and that figure is the figure you pay."
         "If a full repair cannot be finished that night &ndash; a panel that has to be ordered, for instance &ndash; we make the door safe, secure and closable before we leave, so the house is never left open."
       ) }
    @{ H2 = "Covering Venice Island, South Venice and the Tamiami Trail"
       P  = @(
         "We keep trucks working the island and the mainland side of the bridges, from the streets around Venice Ave and the beach down through South Venice and out along Jacaranda Blvd and Laurel Rd. Gated and 55+ communities are part of the daily route, and we follow their access rules."
         "Call and describe what the door is doing. We will tell you on the phone whether it sounds like a same-night fix."
       ) }
  )
  Faqs = @(
    ,@("Is it safe to open my garage door by hand in an emergency?",
       "Only if the springs and cables are intact. With a broken spring the door is far heavier than it looks and can drop without warning. If the door is balanced, pull the red release with the door fully closed and lift slowly from the bottom; if it feels heavy or lopsided, stop and call us.")
    ,@("Will you come out at night in Venice?",
       "Yes. Emergency cover runs 24/7, weekends and holidays included. A door stuck open overnight is exactly the call we keep technicians available for.")
    ,@("My door came down on its own and will not go back up. What happened?",
       "Usually a broken spring or a snapped cable, sometimes an opener that has lost its travel limits. Leave it closed and unplug the opener; we diagnose it on arrival and give you the price before we start.")
    ,@("Do you handle commercial door emergencies in Venice too?",
       "Yes. Roll-up doors and storefront operators are repaired out of hours, because a door that will not open can mean a business that cannot either.")
  )
}

# ================================================================ ENGLEWOOD
"spring|garage-door-repair-englewood-fl" = @{
  Title  = "Garage Door Spring Repair Englewood FL | Salt-Air Springs"
  Desc   = "Garage door spring repair in Englewood, FL with galvanized springs built for salt air on Manasota Key and Lemon Bay. Same day. Call $P."
  H1     = "Garage Door Spring Repair in Englewood, FL"
  HeroH2 = "Galvanized Springs That Stand Up to Gulf Salt on Manasota Key"
  Intro  = @{
    H2 = "Why springs break early on Englewood garage doors"
    P  = @(
      "A spring is a coil of tempered steel under constant tension, and salt is what finds its weak spot. Within a mile or two of the Gulf, an ordinary oil-tempered spring picks up surface rust in its first season, the rust pits the wire, and the pit becomes the point where the coil snaps &ndash; often years before the spring's cycle rating says it should."
      "That is why so many of the broken springs we replace on Manasota Key and around Lemon Bay are not worn out at all. They are corroded. Replacing them like-for-like just starts the same clock again."
    )
  }
  Blocks = @(
    @{ H2 = "Galvanized versus oil-tempered springs on the Englewood coast"
       P  = @("We quote both, because the right choice depends on how close you live to the water:")
       L  = @(
         "<strong>Galvanized springs</strong>: zinc-coated wire that resists salt far better than bare steel. Our first recommendation for Manasota Key, the Lemon Bay waterfront and any garage that faces the Gulf breeze."
         "<strong>Oil-tempered springs</strong>: the standard black spring. A little cheaper and perfectly sound for inland homes off McCall Rd or in Rotonda West, as long as they are kept lubricated."
         "<strong>Stainless cable to match</strong>: a new spring on a rusted cable is half a repair. We check the lift cables and drums and replace corroded ones on the same visit."
         "<strong>Free-running bearings</strong>: the end bearings on the shaft seize in salt air and make a new spring work harder than it should. We replace them when they bind."
       ) }
    @{ H2 = "Rinse, lubricate, inspect: keeping coastal springs alive"
       P  = @(
         "Even a galvanized spring lasts longer with a little care. Every few months, wipe the springs and cables with a damp cloth to lift the salt film, let them dry, and apply a light coat of garage-door lubricant along the coils. Do not pressure-wash the hardware &ndash; it drives salt water into the bearings."
         "If you see orange bloom on the coils, fraying on a cable, or a door that suddenly feels heavy by hand, call before the spring makes the decision for you."
       ) }
    @{ H2 = "Same-day spring replacement from Placida to Manasota Key"
       P  = @(
         "Our trucks run through Englewood every day with galvanized springs in the common sizes on board, so most broken-spring calls are fixed on the first visit &ndash; Manasota Key, the streets off Dearborn St, Cape Haze and Placida included. Crossing the bridge to the key does not change the appointment or the price."
         "You get the price before work starts, the same rate seven days a week, and a door balanced by hand before we leave."
       ) }
  )
  Faqs = @(
    ,@("How long do galvanized springs last in Englewood?",
       "Their cycle rating is similar to a standard spring of the same size, but on the coast a galvanized spring is far less likely to snap early from corrosion. Near the water that often means several extra years before it needs replacing.")
    ,@("Are galvanized springs louder or harder to adjust?",
       "They can feel a little stiffer when new and need a coat of lubricant after fitting, which we apply. Once settled they run as quietly as an oil-tempered spring.")
    ,@("My spring is rusty but not broken. Should I replace it now?",
       "If the rust has pitted the wire, yes &ndash; pitted coils fail without warning. Light surface rust can be cleaned off and lubricated. We will look and tell you honestly which one you have.")
    ,@("Do you replace springs on Manasota Key the same day?",
       "Usually, yes. We carry the common sizes on the truck, and the key is part of our daily Englewood route.")
  )
}

"maintenance|garage-door-repair-englewood-fl" = @{
  Title  = "Garage Door Maintenance Englewood FL | Salt-Air Tune-Ups"
  Desc   = "Garage door maintenance in Englewood, FL: corrosion checks, lubrication and hardware re-torque for salt-air homes near Lemon Bay. Call $P."
  H1     = "Garage Door Maintenance in Englewood, FL"
  HeroH2 = "Corrosion Control for Garage Doors Near Lemon Bay and the Gulf"
  Intro  = @{
    H2 = "Garage door maintenance in Englewood is mostly corrosion control"
    P  = @(
      "Inland, a garage door tune-up is about wear. In Englewood it is about salt. The breeze off the Gulf and Lemon Bay carries a fine salt film into every garage, and it settles on the hinges, rollers, cables and fasteners where nobody looks. Left alone, it turns smooth parts rough and sound bolts into rusted stubs."
      "Our Englewood maintenance visit is built around that: we clean the salt off, treat what has started to corrode, replace what is past saving, and leave the door lubricated with products that hold up in coastal air."
    )
  }
  Blocks = @(
    @{ H2 = "Our coastal tune-up, point by point"
       L  = @(
         "<strong>Hardware re-torque</strong>: hinge screws and track brackets corrode and loosen together. We check every fixing and replace rusted ones with coated or stainless hardware."
         "<strong>Cable and drum inspection</strong>: cables rust from the bottom strand up, right where they meet the bottom bracket. We look there first."
         "<strong>Roller check</strong>: steel rollers seize in salt and sealed nylon ones do not. We flag the ones that drag."
         "<strong>Spring condition</strong>: coils inspected for pitting, with tension and balance tested with the opener disconnected."
         "<strong>Bottom seal</strong>: a hardened or split seal lets wind-driven rain under the door. We fit a coastal-grade gasket when it is gone."
         "<strong>Opener and sensors</strong>: damp salt air is hard on circuit boards and photo eyes. We clean, test and realign them."
       ) }
    @{ H2 = "How often Englewood doors need a service visit"
       P  = @(
         "For homes on Manasota Key and along the Lemon Bay waterfront we recommend a visit every six months. Further inland, off McCall Rd or in Rotonda West, once a year is usually enough. A door that faces the water directly, or a garage left open for long stretches, belongs at the more frequent end."
         "Between visits, a damp-cloth wipe of the springs and cables every couple of months removes most of the salt before it does any damage."
       ) }
    @{ H2 = "Storm-season checks for Englewood garage doors"
       P  = @(
         "The garage door is the largest opening in most homes and the first thing a storm tests. Before hurricane season we check the track fixings, the hinges and any wind-load struts already on the door, so you know it is holding together the way it should rather than finding out in a gust. Where hardware has rusted or worked loose, we replace it then."
         "Book it in May or early June and the door goes into the season with sound fixings and fresh seals."
       ) }
  )
  Faqs = @(
    ,@("What lubricant should I use on a garage door near the beach?",
       "A silicone or lithium-based garage-door lubricant. Avoid penetrating oils and general-purpose sprays; they wash off quickly and leave a tacky film that holds salt and sand against the metal.")
    ,@("Is it worth swapping steel rollers for nylon in Englewood?",
       "Usually, yes. Sealed nylon rollers do not rust, run more quietly and last far longer in salt air. On a coastal door it is one of the most cost-effective changes you can make.")
    ,@("Can rusted hinges be replaced without touching the panels?",
       "Yes. Hinges, brackets and fasteners unbolt from the sections. As long as the steel around them is sound, we replace the hardware and leave the panels exactly as they are.")
    ,@("Do you service doors on Manasota Key and in Placida?",
       "Yes, both are on our regular Englewood route, and the price is the same as anywhere else in town.")
  )
}

"emergency|garage-door-repair-englewood-fl" = @{
  Title  = "Emergency Garage Door Repair Englewood FL | 24/7 Service"
  Desc   = "Emergency garage door repair in Englewood, FL. Snapped cable, storm-bent track or a door stuck open? 24/7, coastal-grade parts. Call $P."
  H1     = "Emergency Garage Door Repair in Englewood, FL"
  HeroH2 = "Storm Damage, Snapped Cables and Stuck Doors Fixed Day or Night"
  Intro  = @{
    H2 = "When an Englewood garage door fails without warning"
    P  = @(
      "Coastal hardware rarely gives notice. A cable that looked fine in spring lets go in September; a roller that has been seizing for months finally binds and drags the door off its track. In Englewood most emergencies are corrosion failures, and they tend to happen at the worst possible moment."
      "We answer around the clock, and our trucks carry stainless cable, galvanized springs and sealed rollers, so the emergency repair is also the repair that lasts. Most calls in town see a technician within 60 to 90 minutes."
    )
  }
  Blocks = @(
    @{ H2 = "Emergency garage door problems we fix in Englewood"
       L  = @(
         "<strong>Snapped lift cable</strong>: the door hangs crooked or drops on one side. We replace both cables with stainless and rebalance the door."
         "<strong>Door pushed off its track</strong>: by high wind or a seized roller. We reseat the rollers, straighten or replace the track and check every fixing."
         "<strong>Door stuck open after a power cut</strong>: openers lose their limits and boards fail after storms. We reset or repair the opener and make sure the manual release works."
         "<strong>Sections bent by storm debris</strong>: secured the same night, with a matching panel ordered where one is beyond saving."
         "<strong>Broken spring</strong>: replaced with a galvanized spring on the first visit &ndash; details on our <a href=""[[spring]]"">Englewood spring repair</a> page."
       ) }
    @{ H2 = "After a storm: making an Englewood garage door safe"
       P  = @(
         "If a storm has damaged the door, do not try to force it open or closed. A bent section or kinked track can let the door twist and fall, and a damaged spring may be holding far more tension than it looks. Keep clear, unplug the opener, and call us."
         "We make the door safe and secure first, so the house can be closed up, and then quote the full repair. If parts have to be ordered, you are not left with an open garage in the meantime."
       ) }
    @{ H2 = "24/7 cover from Manasota Key to Rotonda West"
       P  = @(
         "Emergency calls come from all over Englewood &ndash; the Manasota Key beach houses, the waterfront streets around Lemon Bay, the homes off McCall Rd and Dearborn St, and out to Rotonda West, Cape Haze and Placida. Same rate seven days a week, no weekend or holiday surcharge, and the price agreed before any work begins."
       ) }
  )
  Faqs = @(
    ,@("My garage door cable snapped. Can I still close the door?",
       "Not safely. With one cable gone the door lifts unevenly and can jam or fall. Leave it where it is, keep people and cars clear, and call us &ndash; cable repair is one of our most common same-day jobs.")
    ,@("Do you repair garage doors damaged in storms?",
       "Yes. We repair bent track, damaged sections, broken hinges and storm-tripped openers, and we secure the door first so the house is not left open.")
    ,@("Will you come out to Manasota Key at night?",
       "Yes. Emergency cover is 24/7 and the key is part of our Englewood route, day or night.")
    ,@("Do you charge more for emergency repairs in Englewood?",
       "No. The rate is the same at night, at weekends and on holidays, and the technician gives you the price before starting.")
  )
}

# =============================================================== NORTH PORT
"spring|garage-door-repair-north-port-fl" = @{
  Title  = "Garage Door Spring Repair North Port FL | High-Cycle Springs"
  Desc   = "Garage door spring repair in North Port, FL. Heavy-duty high-cycle springs for busy family doors, fitted the same day. Call $P."
  H1     = "Garage Door Spring Repair in North Port, FL"
  HeroH2 = "High-Cycle Springs for Doors That Open Ten Times a Day"
  Intro  = @{
    H2 = "Why North Port garage door springs wear out so fast"
    P  = @(
      "Most North Port homes are newer builds, and most of them left the builder with a standard torsion spring rated for around 10,000 cycles. That sounds like plenty until you count: a family door that opens and closes ten times a day &ndash; school run, commute, errands, the kids on bikes &ndash; uses up 10,000 cycles in under three years."
      "So the spring was not faulty. It simply reached the end of the life it was built for. Replace it like-for-like and you will be calling again in another three years."
    )
  }
  Blocks = @(
    @{ H2 = "High-cycle springs: the math for a busy North Port door"
       P  = @("A high-cycle spring uses heavier wire and a longer coil to carry the same door with less stress on each turn. What that gets you:")
       L  = @(
         "<strong>Several times the cycle life</strong>: high-cycle springs are rated for 20,000 cycles or more, which on the same busy door means many more years between replacements."
         "<strong>Lower cost per year</strong>: they cost more up front than a builder-grade spring, but far less over the time they last."
         "<strong>Both springs at once</strong>: on a two-spring door we replace the pair, so you are not back in six months for the other side."
         "<strong>Balanced and tested</strong>: the door is set to hold at mid-height by hand, then run on the opener to check the force settings."
       ) }
    @{ H2 = "Signs your North Port garage door spring is about to go"
       L  = @(
         "<strong>The door feels heavy by hand</strong>: with the opener disconnected, a healthy door lifts with one hand. A heavy one means the spring has lost tension."
         "<strong>It will not stay half open</strong>: a door that drifts down or creeps up from waist height is out of balance."
         "<strong>The opener strains or reverses</strong>: often blamed on the motor, often the spring behind it."
         "<strong>A visible gap in the coil</strong>: that spring has already broken. Leave the door closed and call."
       ) }
    @{ H2 = "Same-day spring replacement across North Port"
       P  = @(
         "We hold same-day slots back for broken springs, because a door that will not open at 7am takes the whole family's morning with it. Calls from the neighborhoods off Price Blvd, Sumter Blvd and Toledo Blade Blvd, Heron Creek and the streets around Warm Mineral Springs normally get a technician the same day."
         "The price is agreed before the old spring comes off, and it does not change for a weekend."
       ) }
  )
  Faqs = @(
    ,@("How long should a garage door spring last in North Port?",
       "A builder-grade spring on a busy family door often lasts only three to five years. A high-cycle spring on the same door can last two or three times as long. How often your door runs matters more than its age.")
    ,@("Can I just replace the one spring that broke?",
       "You can, but on a two-spring door the other is the same age and has done the same work. We recommend the pair, and the second spring costs far less fitted now than on a second visit.")
    ,@("Why did my new-build home come with such short-lived springs?",
       "Builders fit the standard spring that suits the door's weight at the lowest cost. It is the right size, just not the longest-lasting. Moving to high-cycle when it breaks is the usual fix.")
    ,@("Is it the spring or the opener?",
       "Disconnect the opener with the door closed and try lifting by hand. If the door is heavy or will not stay put, it is the spring. If it lifts easily and balances, the problem is more likely the opener &ndash; and we repair both.")
  )
}

"maintenance|garage-door-repair-north-port-fl" = @{
  Title  = "Garage Door Maintenance North Port FL | 25-Point Tune-Up"
  Desc   = "Garage door maintenance in North Port, FL. A 25-point tune-up for high-use family doors: rollers, hinges, springs and safety tests. Call $P."
  H1     = "Garage Door Maintenance in North Port, FL"
  HeroH2 = "Tune-Ups Built for Busy Family Doors in North Port"
  Intro  = @{
    H2 = "A busy North Port door needs maintenance, not just repairs"
    P  = @(
      "Garage doors in North Port work harder than average. In a growing city full of young families, the garage is the front door for most comings and goings, and it can run ten or more times a day. All that use wears the rollers, loosens the hinges and eats into the spring's life faster than the builder planned for."
      "A tune-up is how you stop that wear turning into a breakdown on a weekday morning. It costs far less than an emergency call, and it is the cheapest way to make high-use hardware last."
    )
  }
  Blocks = @(
    @{ H2 = "Inside our 25-point garage door tune-up"
       L  = @(
         "<strong>Balance and spring tension</strong>: the door is disconnected and tested by hand, then adjusted so the opener is not doing the spring's job."
         "<strong>Rollers</strong>: cheap steel rollers wear flat on a busy door. We flag them and recommend sealed nylon when they are going."
         "<strong>Hinges and brackets</strong>: re-tightened and checked for cracks around the screw holes, a common failure on high-cycle doors."
         "<strong>Track alignment</strong>: a track knocked out of line by a bike or a bin makes the door bind. We straighten and re-fix it."
         "<strong>Opener settings</strong>: travel limits and force reset, belt or chain tension adjusted, and the battery backup tested if you have one."
         "<strong>Lubrication</strong>: hinges, rollers, bearings and springs treated with garage-door lubricant."
       ) }
    @{ H2 = "Safety checks for North Port homes with kids and pets"
       P  = @(
         "A garage door is the heaviest moving object in most homes, and in a house with children, bikes and pets it closes over a lot of traffic. Part of every tune-up is the safety-reverse test: we place an obstruction under the door, check that it reverses on contact, and confirm the photo eyes stop it before it gets there."
         "If your opener is old enough to predate those protections, we tell you plainly. We also check the manual release, so the door can be opened by hand in a power cut."
       ) }
    @{ H2 = "Smart opener checks during your North Port tune-up"
       P  = @(
         "Many North Port homes now open the garage from a phone. During maintenance we confirm the WiFi opener is connected, the alerts are firing and the keypad code is one you actually want to keep. If the app has dropped off the network, we re-pair it before we leave."
         "We cover the neighborhoods off Price Blvd, Sumter Blvd, Toledo Blade Blvd and the Tamiami Trail, at one rate seven days a week."
       ) }
  )
  Faqs = @(
    ,@("How often should a high-use garage door be serviced?",
       "For a North Port family door that runs ten times a day, every six months is sensible. Lighter use can go a year between visits.")
    ,@("What is included in the 25-point tune-up?",
       "Springs, cables, drums, rollers, hinges, track, fixings, weather seal, the opener and its force and travel settings, the photo eyes and the safety reverse &ndash; inspected, adjusted and lubricated, with anything worn priced before we replace it.")
    ,@("Will a tune-up make my garage door quieter?",
       "Usually noticeably. Lubrication and re-tightening take out a lot of rattle; swapping worn steel rollers for sealed nylon takes out most of the rest.")
    ,@("Can you check my smart opener during the visit?",
       "Yes. We test the app connection, alerts and keypad, and re-pair the opener to your WiFi if it has dropped off.")
  )
}

"emergency|garage-door-repair-north-port-fl" = @{
  Title  = "Emergency Garage Door Repair North Port FL | 24/7 Service"
  Desc   = "Emergency garage door repair in North Port, FL. Car stuck inside or door off track? Same-day slots held back, 24/7. Call $P."
  H1     = "Emergency Garage Door Repair in North Port, FL"
  HeroH2 = "Car Trapped Before the School Run? We Hold Same-Day Slots for That"
  Intro  = @{
    H2 = "Garage door emergencies in North Port, and how fast we respond"
    P  = @(
      "In North Port the most common emergency call is not dramatic. It is a family with the car inside, a door that refuses to move, and a school run and a commute up I-75 waiting. That is why we keep same-day slots free in the schedule for doors that will not open at all."
      "Call, tell us what the door is doing, and we give you an arrival time on the phone. Out of hours, someone still answers."
    )
  }
  Blocks = @(
    @{ H2 = "Fast fixes for the most common North Port breakdowns"
       L  = @(
         "<strong>Door will not open with the car inside</strong>: usually a broken spring or a failed opener. We diagnose it on arrival and get the car out first."
         "<strong>Door off the track</strong>: often after a bump from a car or a bike. We reseat the rollers, straighten the track and find out what pushed it over."
         "<strong>Opener dead or app offline</strong>: boards, gears, belts and WiFi modules repaired, or a new opener fitted when the old one is not worth saving."
         "<strong>Door reverses before it closes</strong>: photo eyes knocked out of line or blocked. Realigned and tested on the spot."
         "<strong>Snapped cable</strong>: the door hangs crooked. Both cables replaced and the door rebalanced."
       ) }
    @{ H2 = "Getting your car out of a North Port garage safely"
       P  = @(
         "If the springs and cables are intact, the opener's red release cord lets you lift the door by hand. Pull it only with the door fully closed, then lift slowly from the bottom. If the door feels heavy, drops or sits crooked, stop: something has broken, and a door without its spring can weigh more than you can safely hold."
         "If in doubt, leave it and call. We would rather spend ten minutes on the phone than have anyone hurt for the sake of getting to work on time. If it does turn out to be the spring, our <a href=""[[spring]]"">North Port spring repair</a> page explains what we fit and why."
       ) }
    @{ H2 = "24/7 emergency service from Warm Mineral Springs to Heron Creek"
       P  = @(
         "We cover all of North Port &ndash; the streets off Price Blvd, Sumter Blvd and Toledo Blade Blvd, Heron Creek, the Warm Mineral Springs area and along the Tamiami Trail. One rate at any hour, no weekend surcharge, and a price agreed before the work starts."
       ) }
  )
  Faqs = @(
    ,@("How fast can you get to an emergency in North Port?",
       "We keep same-day slots back for doors that will not open, and most North Port emergency calls get a technician the same day, often within 60 to 90 minutes.")
    ,@("My car is stuck in the garage. Should I force the door?",
       "No. Try the red release cord only if the door is balanced and the springs are intact. If it is heavy or crooked, leave it and call; we will get the car out safely.")
    ,@("Can you fix a garage door that a car backed into?",
       "Yes. We straighten or replace the track and hinges, secure the damaged sections, and match a replacement panel when one is beyond repair.")
    ,@("Do you repair WiFi and smart openers as an emergency?",
       "Yes. We repair and reconnect smart openers, and replace them when the repair would cost more than the motor is worth.")
  )
}

# ================================================================= SARASOTA
"spring|garage-door-repair-sarasota-fl" = @{
  Title  = "Garage Door Spring Repair Sarasota FL | Same-Day Service"
  Desc   = "Garage door spring repair in Sarasota, FL. Galvanized springs for Longboat Key and Siesta Key, high-cycle springs inland. Call $P."
  H1     = "Garage Door Spring Repair in Sarasota, FL"
  HeroH2 = "Galvanized Springs for the Keys, High-Cycle Springs Inland"
  Intro  = @{
    H2 = "The right garage door spring depends on where in Sarasota you live"
    P  = @(
      "Sarasota is two climates for a garage door spring. On Longboat Key, Lido Key and Siesta Key the hardware lives in salt air a few hundred yards from the Gulf, and the enemy is corrosion. Inland, in Lakewood Ranch, Palmer Ranch and the neighborhoods along University Pkwy, the air is gentler and the enemy is simply use."
      "So we do not fit one spring for the whole county. Galvanized springs are the right answer for beachfront properties like those on Longboat Key; a high-cycle spring is usually the better buy for a busy family door further inland."
    )
  }
  Blocks = @(
    @{ H2 = "Galvanized springs for Longboat Key, Lido Key and Siesta Key"
       P  = @("Close to the water a bare oil-tempered spring rusts, the rust pits the wire, and the pit is where it breaks. A galvanized spring is zinc-coated against exactly that:")
       L  = @(
         "<strong>Corrosion resistance</strong>: far slower to rust in salt air, so the spring reaches its rated cycle life instead of snapping early."
         "<strong>Matched hardware</strong>: we check the cables, drums and bearings at the same time, because a new spring on a corroded cable only moves the failure point."
         "<strong>Lubricated on fitting</strong>: galvanized coils need a coat of lubricant to run smoothly and quietly, and we apply it before we leave."
       ) }
    @{ H2 = "Heavy impact-rated doors need the right spring size"
       P  = @(
         "Many Sarasota homes, especially newer builds in Lakewood Ranch and Palmer Ranch, have impact-rated doors with window sections and insulated panels. Those doors weigh considerably more than a plain single-skin door, and the spring has to be sized to the real weight. An undersized spring wears out fast and leaves the opener doing the lifting."
         "We measure the door, read the specification of the spring that broke, and fit a matched pair of springs, then balance the door by hand. On an ARC street nothing about the outside changes, so there is nothing for the committee to review."
       ) }
    @{ H2 = "Same-day spring repair from Lakewood Ranch to Siesta Key"
       P  = @(
         "Our trucks are staged along the I-75 corridor near Fruitville Rd and Bee Ridge Rd, so a broken spring anywhere in Sarasota is normally a same-day call &ndash; out to Lakewood Ranch in the east and across the bridges to Siesta Key, Lido Key and Longboat Key in the west. You get the price on the driveway, before the old spring comes off."
       ) }
  )
  Faqs = @(
    ,@("Do I need galvanized springs if I live on Longboat Key?",
       "We strongly recommend them. On the barrier islands an ordinary spring often corrodes and breaks well before its cycle rating. Galvanized springs cost a little more and usually last much longer near the water.")
    ,@("Why did the spring on my Lakewood Ranch door break so soon?",
       "Most likely it was a standard builder-grade spring on a heavy, well-used door. We size the replacement to the door's real weight and offer high-cycle springs so the next one lasts.")
    ,@("Will a new spring change how my door looks to the HOA?",
       "No. Springs sit inside the garage above the door. The exterior is untouched, so a spring repair needs no committee approval.")
    ,@("How quickly can you replace a broken spring in Sarasota?",
       "Usually the same day. Our trucks run the Fruitville and Bee Ridge corridors and carry the common spring sizes, galvanized included.")
  )
}

"maintenance|garage-door-repair-sarasota-fl" = @{
  Title  = "Garage Door Maintenance Sarasota FL | Tune-Ups & Checks"
  Desc   = "Garage door maintenance in Sarasota, FL: lubrication, hardware checks and hurricane-season inspections across the county. Call $P."
  H1     = "Garage Door Maintenance in Sarasota, FL"
  HeroH2 = "Gulf Humidity Works on Hardware All Year. We Keep Ahead of It"
  Intro  = @{
    H2 = "What Sarasota humidity does to an unserviced garage door"
    P  = @(
      "Sarasota's air is wet for most of the year, and the garage is where that humidity sits. Lubricant breaks down faster, bare steel rollers and hinges start to rust, cable strands fray from the inside, and the opener's circuit board takes on moisture every summer. None of it shows from the driveway until something binds."
      "Regular maintenance keeps the door ahead of the climate: clean, lubricated hardware, correct balance, and the small worn parts caught before they take a bigger one with them."
    )
  }
  Blocks = @(
    @{ H2 = "What a Sarasota garage door tune-up includes"
       L  = @(
         "<strong>Lubrication that lasts in humidity</strong>: hinges, rollers, bearings and springs treated with a garage-door lubricant that does not wash out in the wet season."
         "<strong>Rust check on every fixing</strong>: hinges, brackets and track bolts inspected and replaced where corrosion has started."
         "<strong>Cable and spring inspection</strong>: fraying and pitting found early, with tension and balance reset."
         "<strong>Opener service</strong>: drive tension, travel limits, force settings and the MyQ or app connection tested."
         "<strong>Safety tests</strong>: photo eyes aligned and the auto-reverse tested against an obstruction."
         "<strong>Seal check</strong>: bottom and side seals inspected so summer storms stay on the driveway."
       ) }
    @{ H2 = "A pre-hurricane-season inspection for Sarasota homes"
       P  = @(
         "Hurricane season starts on June 1, and the garage door is usually the largest opening in the house. Book a maintenance visit in May and we check the fixings, hinges, track and any wind-load bracing the door already has, and replace hardware that has rusted or worked loose. It is far easier to tighten a door in May than to secure one in a storm."
         "On the keys we look harder at corrosion; inland we look harder at wear. The checklist is the same, the emphasis is not."
       ) }
    @{ H2 = "Maintenance that keeps ARC-street doors looking approved"
       P  = @(
         "In Lakewood Ranch, Palmer Ranch and the other review-committee communities, a door that sags, gaps at the bottom or runs crooked draws attention. Routine maintenance keeps the seals tight, the sections level and the door running straight, and we treat the outside hardware so it does not streak rust down the paint."
         "We cover all of Sarasota, from the Fruitville and Bee Ridge neighborhoods to University Pkwy and the barrier islands, at one rate seven days a week."
       ) }
  )
  Faqs = @(
    ,@("How often should I service my garage door in Sarasota?",
       "Once a year inland, and every six months on Siesta Key, Lido Key or Longboat Key, where salt air speeds up corrosion. A visit before hurricane season is a good habit either way.")
    ,@("Can maintenance extend the life of my garage door opener?",
       "Yes. A balanced door on free-running rollers takes most of the strain off the motor. Many opener failures we see start as a door the opener was having to drag.")
    ,@("Do you check the door's hurricane bracing during maintenance?",
       "We inspect any wind-load struts and bracing already fitted, along with the track and hinges, and tighten or replace hardware that has loosened or corroded.")
    ,@("Do you service garage doors in gated communities?",
       "Yes. We work in Lakewood Ranch, Palmer Ranch and other gated communities every week and follow their access and working-hours rules.")
  )
}

"emergency|garage-door-repair-sarasota-fl" = @{
  Title  = "Emergency Garage Door Repair Sarasota FL | 24/7 Response"
  Desc   = "Emergency garage door repair in Sarasota, FL. Trucks staged on the I-75 corridor for fast dispatch, day or night. No weekend surcharge. Call $P."
  H1     = "Emergency Garage Door Repair in Sarasota, FL"
  HeroH2 = "Trucks Staged Near I-75 for Fast Night and Weekend Dispatch"
  Intro  = @{
    H2 = "Garage door stuck in Sarasota? Our trucks are already nearby"
    P  = @(
      "Our service trucks are staged along the I-75 corridor near Fruitville Rd, which puts most of Sarasota within easy reach. For emergency calls we aim to have a technician at the door within 45 to 60 minutes, day or night, weekends included."
      "Tell us on the phone what the door is doing &ndash; stuck open, stuck shut, hanging crooked, making a noise it did not make yesterday &ndash; and we will tell you what we think it is and when we will be there."
    )
  }
  Blocks = @(
    @{ H2 = "Sarasota emergency repairs, usually done in one visit"
       L  = @(
         "<strong>Door stuck open overnight</strong>: opener, sensor or track fault found and fixed, or the door secured shut until parts arrive."
         "<strong>Off-track door</strong>: rollers reseated, track straightened or replaced, cables re-tensioned so it hangs level."
         "<strong>Cable snapped or off the drum</strong>: both cables replaced and the door rebalanced."
         "<strong>Section damaged by a vehicle</strong>: secured the same day, then a panel matched in profile and color to the rest of the door."
         "<strong>Broken spring</strong>: replaced on the same visit, galvanized near the water &ndash; see our <a href=""[[spring]]"">Sarasota spring repair</a> page."
       ) }
    @{ H2 = "Emergency panel repair on HOA and ARC streets"
       P  = @(
         "A car into the door on an ARC street is two problems: the damage, and keeping the repaired door looking like the one the committee approved. We secure the door first so the house can be closed, then order a section matched to the panel profile and factory color of the rest, so the finished repair needs no new submission."
         "We bring the spec sheet with us in case your committee wants it on file."
       ) }
    @{ H2 = "24/7 garage door help from Lakewood Ranch to Longboat Key"
       P  = @(
         "We answer around the clock across Sarasota &ndash; Fruitville and Bee Ridge, University Pkwy, Palmer Ranch, Lakewood Ranch, and over the bridges to Siesta Key, Lido Key and Longboat Key. Gated-community access rules are part of the job. One rate at every hour, no holiday surcharge, and the price agreed before any work."
       ) }
  )
  Faqs = @(
    ,@("How fast can you reach an emergency in Sarasota?",
       "Most emergency calls are reached within 45 to 60 minutes, because our trucks are staged near I-75 and Fruitville Rd rather than driving in from another county.")
    ,@("Can you secure a garage door that will not close tonight?",
       "Yes. If the full repair needs a part we do not carry, we lock the door down safely so the house is not left open, then come back to finish.")
    ,@("Do you charge extra for a Sunday or holiday emergency?",
       "No. The rate is the same every day and every hour, and you get the price before any work begins.")
    ,@("Can you match a damaged panel on a Lakewood Ranch door?",
       "In most cases, yes. We match the panel profile and factory color so the repair reads as part of the original door.")
  )
}

}
