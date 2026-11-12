import type { SyntaxKey } from './theme-file'

export const DEFAULT_SYNTAX: Record<'dark' | 'light', Record<SyntaxKey, string>> = {
  dark: {
    keyword: '#96a0a8', string: '#98c379', comment: '#7f848e', function: '#eca654',
    type: '#e5c07b', number: '#d19a66', operator: '#c9973f', property: '#d19a66',
    tag: '#e06c75', variable: '#abb2bf', constant: '#d19a66', heading: '#96a0a8',
    link: '#98c379', list: '#d19a66', quote: '#abb2bf', meta: '#abb2bf',
    mark: '#96a0a8', invalid: '#f44747',
    'active-line-bg': 'rgba(255, 255, 255, 0.04)',
    'selection-bg': 'rgba(201, 151, 63, 0.35)',
    'selection-match-bg': 'rgba(255, 255, 255, 0.06)',
  },
  light: {
    keyword: '#7c3a30', string: '#50a14f', comment: '#696c77', function: '#c9973f',
    type: '#c18401', number: '#986801', operator: '#7d5f2a', property: '#986801',
    tag: '#e45649', variable: '#383a42', constant: '#986801', heading: '#7c3a30',
    link: '#50a14f', list: '#986801', quote: '#696c77', meta: '#696c77',
    mark: '#7c3a30', invalid: '#d52753',
    'active-line-bg': 'rgba(0, 0, 0, 0.035)',
    'selection-bg': 'rgba(201, 151, 63, 0.22)',
    'selection-match-bg': 'rgba(0, 0, 0, 0.05)',
  },
}
