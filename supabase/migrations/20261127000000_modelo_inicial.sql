-- Modelo inicial a partir de docs/modelo-er/modelo-entidad-relacion.png
-- Decisión: CAMPO y GYM son 1:N respecto a DÍA (varias sesiones por día),
-- con clave (dni, fecha, hora_inicio).

-- JUGADORA
create table public.jugadora (
  dni               text primary key,
  nombre_apellidos  text not null,
  fecha_nacimiento  date,
  estatura_m        numeric(3,2) check (estatura_m > 0)
);

-- EQUIPO-TEMPORADA
create table public.equipo_temporada (
  categoria          text not null,
  equipo             text not null,
  temporada          text not null,
  fecha_inicio       date,
  fecha_fin          date,
  nivel_competicion  text,
  preparador_fisico  text,
  primary key (categoria, equipo, temporada)
);

-- PERTENECE (N:M jugadora <-> equipo_temporada)
create table public.pertenece (
  dni        text not null references public.jugadora (dni)
               on update cascade on delete cascade,
  categoria  text not null,
  equipo     text not null,
  temporada  text not null,
  posicion   text,
  activa     boolean not null default true,
  primary key (dni, categoria, equipo, temporada),
  foreign key (categoria, equipo, temporada)
    references public.equipo_temporada (categoria, equipo, temporada)
    on update cascade on delete cascade
);

-- MEDICIÓN (1 jugadora : N mediciones)
create table public.medicion (
  dni                  text not null references public.jugadora (dni)
                         on update cascade on delete cascade,
  fecha                date not null,
  peso                 numeric(5,2),
  imc                  numeric(5,2),
  sumatorio_pliegues   numeric(6,2),
  momento              text check (momento in ('pretemporada', 'temporada', 'postemporada')),
  responsable          text,
  primary key (dni, fecha)
);

-- LESIÓN (1 jugadora : N lesiones)
create table public.lesion (
  dni                text not null references public.jugadora (dni)
                       on update cascade on delete cascade,
  fecha_accidente    date not null,
  nombre_lesion      text not null,
  gravedad           text,
  zona_corporal      text,
  estado             text check (estado in ('postoperatorio', 'rehabilitación', 'vuelta al campo')),
  alta_medica        boolean not null default false,
  contacto           text check (contacto in ('apto', 'no apto')),
  fecha_alta_medica  date,
  dias_baja          integer check (dias_baja >= 0),
  primary key (dni, fecha_accidente, nombre_lesion)
);

-- WELLNESS (1 jugadora : N registros)
create table public.wellness (
  dni                 text not null references public.jugadora (dni)
                        on update cascade on delete cascade,
  fecha               date not null,
  esfuerzo_percibido  smallint,
  fatiga              smallint,
  dolor_muscular      smallint,
  estado_animo        smallint,
  lesiones            text,
  descanso            smallint,
  ciclo_menstrual     text,
  primary key (dni, fecha)
);

-- CARGA SEMANAL (1 jugadora : N semanas)
create table public.carga_semanal (
  dni                  text not null references public.jugadora (dni)
                         on update cascade on delete cascade,
  fecha_inicio_semana  date not null,
  fecha_fin_semana     date,
  estado               char(1) check (estado in ('V', 'A', 'R')),
  carga_total_semanal  numeric(8,2),
  acwr                 numeric(5,2),
  primary key (dni, fecha_inicio_semana)
);

-- DÍA (1 carga semanal : N días)
create table public.dia (
  dni                  text not null,
  fecha                date not null,
  fecha_inicio_semana  date not null,
  carga_campo          numeric(8,2),
  carga_gym            numeric(8,2),
  carga_total_diaria   numeric(8,2)
    generated always as (coalesce(carga_campo, 0) + coalesce(carga_gym, 0)) stored,
  primary key (dni, fecha),
  foreign key (dni, fecha_inicio_semana)
    references public.carga_semanal (dni, fecha_inicio_semana)
    on update cascade on delete cascade
);

-- CAMPO (1 día : N sesiones de campo)
create table public.campo (
  dni              text not null,
  fecha            date not null,
  hora_inicio      time not null,
  hora_fin         time,
  entrenador       text,
  nivel_contacto   text check (nivel_contacto in ('alto', 'medio', 'bajo')),
  lugar            text,
  tipo             text check (tipo in ('táctica', 'técnica', 'contacto', 'recuperación')),
  duracion_min     integer check (duracion_min >= 0),
  rpe              smallint check (rpe between 0 and 10),
  carga_sesion     integer generated always as (rpe * duracion_min) stored,
  asistencia       boolean not null default true,
  motivo_ausencia  text check (motivo_ausencia in ('trabajo-estudios', 'personal', 'lesión/enfermedad', 'otro')),
  primary key (dni, fecha, hora_inicio),
  foreign key (dni, fecha) references public.dia (dni, fecha)
    on update cascade on delete cascade
);

-- GYM (1 día : N sesiones de gimnasio)
create table public.gym (
  dni              text not null,
  fecha            date not null,
  hora_inicio      time not null,
  hora_fin         time,
  lugar            text,
  tipo_principal   text check (tipo_principal in (
                     'fuerza máxima y potencia',
                     'pliometría',
                     'trabajo de core y estabilidad central',
                     'prehab-prevención de lesiones')),
  objetivo         text,
  duracion_min     integer check (duracion_min >= 0),
  rpe              smallint check (rpe between 0 and 10),
  carga_sesion     integer generated always as (rpe * duracion_min) stored,
  asistencia       boolean not null default true,
  motivo_ausencia  text check (motivo_ausencia in ('trabajo-estudios', 'personal', 'lesión/enfermedad', 'otro')),
  primary key (dni, fecha, hora_inicio),
  foreign key (dni, fecha) references public.dia (dni, fecha)
    on update cascade on delete cascade
);

-- Seguridad: RLS activado en todas las tablas (sin políticas = nadie accede
-- desde la API pública hasta que se añadan políticas).
alter table public.jugadora          enable row level security;
alter table public.equipo_temporada  enable row level security;
alter table public.pertenece         enable row level security;
alter table public.medicion          enable row level security;
alter table public.lesion            enable row level security;
alter table public.wellness          enable row level security;
alter table public.carga_semanal     enable row level security;
alter table public.dia               enable row level security;
alter table public.campo             enable row level security;
alter table public.gym               enable row level security;
