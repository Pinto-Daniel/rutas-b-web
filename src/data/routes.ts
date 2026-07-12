export type RouteStatus = 'available' | 'in-development' | 'coming-soon';

export interface TourRoute {
  slug: string;
  title: string;
  eyebrow: string;
  promise: string;
  description: string;
  status: RouteStatus;
  statusLabel: string;
  duration: string;
  format: string;
  area: string;
  languages: string[];
  audience: string[];
  startingPoint: string;
  endingPoint: string;
  stops: string[];
  includes: string[];
  notIncluded: string[];
  accessibility: string;
  priceIndividual: string;
  priceGroup: string;
  image: string;
  imageAlt: string;
  featured: boolean;
  published: boolean;
}

export const routes: TourRoute[] = [
  {
    slug: 'sagrada-familia',
    title: 'De Gaudí a la Sagrada Familia',
    eyebrow: 'Arquitectura · ciudad · obra viva',
    promise: 'Una ruta exterior para comprender la obra más famosa de Barcelona sin reducirla a una postal.',
    description: 'Rodeamos la basílica para descubrir cómo Gaudí, el Eixample, la fe, el oficio y más de un siglo de historia siguen conversando en una obra todavía viva.',
    status: 'available',
    statusLabel: 'Ruta inicial',
    duration: '1 h 30 min–1 h 40 min',
    format: 'Exterior · caminata corta · 4 paradas',
    area: 'Sagrada Família',
    languages: ['Español', 'English'],
    audience: ['Viajeros individuales', 'Parejas', 'Grupos pequeños', 'Hoteles y agencias', 'Programas educativos'],
    startingPoint: 'Plaça de Gaudí, en un punto con vista abierta hacia la basílica. Ubicación exacta al confirmar.',
    endingPoint: 'Plaça de la Sagrada Família o entorno de la Fachada de la Gloria, según las condiciones del lugar.',
    stops: ['Gaudí, el Eixample y la ciudad', 'Fachada del Nacimiento', 'Fachada de la Pasión', 'Gloria, futuro y Barcelona por venir'],
    includes: ['Guía presencial', 'Ruta interpretativa exterior', 'Cuatro paradas visuales', 'Recomendaciones para continuar la visita'],
    notIncluded: ['Entrada a la basílica', 'Transporte', 'Consumos personales'],
    accessibility: 'Recorrido exterior urbano. La accesibilidad detallada y los ajustes necesarios se confirman antes de la reserva.',
    priceIndividual: 'Pendiente de definición',
    priceGroup: 'Pendiente de definición',
    image: '/images/sagrada-familia.jpg',
    imageAlt: 'Vista de la Sagrada Familia desde una de sus plazas',
    featured: true,
    published: true
  },
  {
    slug: 'barcino',
    title: 'Barcino: entrar a la ciudad por sus capas',
    eyebrow: 'Roma · ciudad medieval · memoria urbana',
    promise: 'Cruzar el Gòtic como una máquina del tiempo, leyendo las capas que Barcelona conserva y reconstruye.',
    description: 'La puerta romana, los acueductos, las murallas y la ciudad medieval abren un recorrido donde cada época ocupa, transforma y vuelve a contar el mismo espacio.',
    status: 'in-development',
    statusLabel: 'En preparación',
    duration: 'Pendiente de cierre',
    format: 'Exterior · recorrido urbano',
    area: 'Barri Gòtic',
    languages: ['Español', 'English'],
    audience: ['Visitantes culturales', 'Grupos pequeños', 'Programas educativos'],
    startingPoint: 'Entorno del COAC / Plaça Nova.',
    endingPoint: 'Pendiente de cierre del recorrido completo.',
    stops: ['Entrada a Barcino', 'Casa de l’Ardiaca', 'Catedral y Sant Iu', 'Palau del Lloctinent y Saló del Tinell', 'Templo de Augusto', 'Pont del Bisbe y Sant Jaume'],
    includes: ['Guía presencial', 'Lectura urbana e histórica del recorrido'],
    notIncluded: ['Entradas a recintos', 'Transporte', 'Consumos personales'],
    accessibility: 'Pendiente de auditoría completa del recorrido.',
    priceIndividual: 'Pendiente de definición',
    priceGroup: 'Pendiente de definición',
    image: '/images/barcino.jpg',
    imageAlt: 'Portal del Bisbe y restos de la muralla romana de Barcelona',
    featured: true,
    published: true
  },
  {
    slug: 'cafeborn',
    title: 'CafèBorn',
    eyebrow: 'Mercados · cultura · pasajes · vida local',
    promise: 'Una Barcelona que se reconoce en sus desayunos, espacios culturales y calles de trabajo cotidiano.',
    description: 'Una experiencia adaptable que conecta el Mercat de Santa Caterina, el Teatre Antic, el Palau de la Música y los pasajes del Born y Sant Pere.',
    status: 'in-development',
    statusLabel: 'En preparación',
    duration: 'Media mañana · duración final pendiente',
    format: 'Caminata cultural · adaptable a público final y partners',
    area: 'Sant Pere, Santa Caterina i la Ribera',
    languages: ['Español', 'English'],
    audience: ['Viajeros individuales', 'Parejas', 'Hoteles', 'Agencias receptivas', 'Grupos privados'],
    startingPoint: 'Pendiente de confirmación comercial.',
    endingPoint: 'Pendiente de confirmación comercial.',
    stops: ['Mercat de Santa Caterina', 'Teatre Antic', 'Palau de la Música', 'Pasajes y memoria del trabajo'],
    includes: ['Guía presencial', 'Relato cultural del barrio'],
    notIncluded: ['Consumos y proveedores hasta cerrar acuerdos', 'Transporte'],
    accessibility: 'Pendiente de auditoría completa del recorrido y sus proveedores.',
    priceIndividual: 'Pendiente de definición',
    priceGroup: 'Pendiente de definición',
    image: '/images/cafeborn.jpg',
    imageAlt: 'Cubierta colorida del Mercat de Santa Caterina',
    featured: true,
    published: true
  }
];

export const publishedRoutes = routes.filter((route) => route.published);
export const getRoute = (slug: string) => publishedRoutes.find((route) => route.slug === slug);
