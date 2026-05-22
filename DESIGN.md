---
name: Neo-Minimalist Design Guide
colors:
  surface: '#faf9fe'
  surface-dim: '#dad9df'
  surface-bright: '#faf9fe'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f4f3f8'
  surface-container: '#eeedf3'
  surface-container-high: '#e9e7ed'
  surface-container-highest: '#e3e2e7'
  on-surface: '#1a1b1f'
  on-surface-variant: '#59413d'
  inverse-surface: '#2f3034'
  inverse-on-surface: '#f1f0f5'
  outline: '#8d716b'
  outline-variant: '#e1bfb9'
  surface-tint: '#ae311e'
  primary: '#ae311e'
  on-primary: '#ffffff'
  primary-container: '#ff6b52'
  on-primary-container: '#6a0700'
  inverse-primary: '#ffb4a6'
  secondary: '#5f5e5e'
  on-secondary: '#ffffff'
  secondary-container: '#e2dfde'
  on-secondary-container: '#636262'
  tertiary: '#5d5f5f'
  on-tertiary: '#ffffff'
  tertiary-container: '#999a9a'
  on-tertiary-container: '#303233'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#ffdad4'
  primary-fixed-dim: '#ffb4a6'
  on-primary-fixed: '#3f0300'
  on-primary-fixed-variant: '#8c1808'
  secondary-fixed: '#e5e2e1'
  secondary-fixed-dim: '#c8c6c5'
  on-secondary-fixed: '#1c1b1b'
  on-secondary-fixed-variant: '#474746'
  tertiary-fixed: '#e2e2e2'
  tertiary-fixed-dim: '#c6c6c7'
  on-tertiary-fixed: '#1a1c1c'
  on-tertiary-fixed-variant: '#454747'
  background: '#faf9fe'
  on-background: '#1a1b1f'
  surface-variant: '#e3e2e7'
typography:
  display:
    fontFamily: Manrope
    fontSize: 48px
    fontWeight: '600'
    lineHeight: 56px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Manrope
    fontSize: 32px
    fontWeight: '600'
    lineHeight: 40px
    letterSpacing: -0.01em
  headline-lg-mobile:
    fontFamily: Manrope
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  headline-md:
    fontFamily: Manrope
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  body-lg:
    fontFamily: Manrope
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Manrope
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-md:
    fontFamily: Manrope
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.01em
  label-sm:
    fontFamily: Manrope
    fontSize: 10px
    fontWeight: '600'
    lineHeight: 12px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 8px
  gutter: 24px
  margin-mobile: 20px
  margin-desktop: 40px
  card-padding: 24px
---

## Brand & Style

This design system embodies a **Neo-minimalist** aesthetic tailored for modern management. The brand personality is sophisticated yet approachable, moving away from traditional "stiff" corporate finance toward a lifestyle-oriented banking experience. 

The visual language relies on generous white space, soft-depth UI elements, and a precise balance between functional data visualization and warm human-centric cues. It aims to evoke a sense of calm control and clarity, reducing cognitive load through a "soft-UI" approach that uses light and shadow rather than heavy lines to define structure.

## Colors

The palette is anchored by a warm, off-white canvas that feels more organic and premium than stark white. 

- **Primary (Coral):** Used sparingly for high-priority actions, accents in data visualization, and status highlights. 
- **Secondary (Ink):** A deep, near-black navy for high-contrast typography and iconography, ensuring maximum legibility.
- **Tertiary (Canvas):** The foundation color for the application background, creating a soft contrast with pure white card surfaces.
- **Neutral:** A range of soft greys used for secondary text, borders, and inactive states.

Data visualization should utilize monochromatic shades of the Primary Coral and complementary warm neutrals to maintain the minimalist harmony.

## Typography

This design system utilizes **Manrope** for its modern, geometric construction and high legibility in data-dense environments. 

The typographic hierarchy is characterized by significant contrast between "Display" and "Body" styles. Headlines should feel tight and integrated, utilizing slight negative letter-spacing. Labels and metadata should maintain a slightly heavier weight (Medium/SemiBold) to remain legible at small sizes against the soft-contrast backgrounds.

## Layout & Spacing

The design system employs a **Fluid Grid** with a 12-column structure for desktop and a 4-column structure for mobile. 

The "Neo-minimalist" feel is achieved through intentional "Air" — high margins and large gutters that prevent the financial data from feeling cramped. Elements are grouped within soft-shadow cards that act as the primary structural units. 

**Breakpoints:**
- **Mobile (< 600px):** 4 Columns, 20px margins, 16px gutters. Cards stack vertically.
- **Tablet (600px - 1024px):** 8 Columns, 32px margins, 20px gutters. 2-column card layouts.
- **Desktop (> 1024px):** 12 Columns, 40px margins, 24px gutters. Complex bento-box card arrangements.

## Elevation & Depth

Depth is defined through **Tonal Layers** and **Ambient Shadows**. Surfaces do not use harsh borders; instead, they rely on a three-tier system:

1.  **Level 0 (Background):** The `#F5F5F5` Tertiary color.
2.  **Level 1 (Cards):** Pure `#FFFFFF` surfaces with a very soft, diffused shadow (`0px 10px 30px rgba(0,0,0,0.04)`).
3.  **Level 2 (Interactive/Floating):** Elements like active buttons or dropdowns, utilizing a slightly more pronounced shadow to indicate clickability.

Avoid inner shadows or heavy bevels. The "depth" should feel like paper layers resting gently on top of one another.

## Shapes

The shape language is defined by high-radius curves that soften the analytical nature of the content. 

The standard corner radius for primary containers and cards is **24px** (represented by `rounded-xl` in this system). Smaller components like buttons and input fields should follow a **12px** to **16px** radius. This consistent "roundedness" creates a friendly, safe, and modern atmosphere appropriate for a consumer-facing financial tool.

## Components

### Buttons
- **Primary:** Solid Coral (`#FF6B52`) with white text. High roundedness (pill-shaped or 16px).
- **Secondary:** Solid Ink (`#1A1A1A`) or a soft tinted ghost button.
- **Icon Buttons:** Circular containers with a soft drop shadow.

### Cards
Cards are the primary container. They must always have a white background, 24px corner radius, and 24px internal padding. Content within cards should be aligned to a sub-grid to maintain internal rhythm.

### Input Fields
Inputs should use a very light grey background or a subtle 1px border in a light neutral. The focus state should transition the border or a subtle outer glow to the Primary Coral.

### Chips & Tags
Used for filtering and status. These should have a high roundedness (pill-shape) and use low-saturation background tints of the primary color to indicate state without over-powering the primary CTA.

### Data Visualization
Graphs should use rounded line caps and "Soft Fill" areas (gradients that fade into the card background). Avoid sharp points or jagged edges.