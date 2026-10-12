#@ destino: ~/.config/swaync/style.css
/* Generado por paleta.sh — paleta: {{nombre}} */
* { font-family: "JetBrainsMono Nerd Font", sans-serif; }
.floating-notifications, .blank-window, .notification-row,
.notification-background, .control-center-list { background: transparent; outline: none; box-shadow: none; }
.notification { background: {{fondo.rgba94}}; border: 2px solid {{acento}}; border-radius: 14px; margin: 6px 10px; padding: 0; box-shadow: 0 4px 14px rgba(0,0,0,0.45); }
.notification.critical { border-color: {{rojo}}; }
.notification-content { background: transparent; padding: 10px; }
.notification-default-action, .notification-action { background: transparent; border: none; border-radius: 12px; color: {{texto}}; }
.notification-default-action:hover, .notification-action:hover { background: {{acento.rgba10}}; }
.summary { color: {{texto}}; font-weight: bold; font-size: 14px; }
.body { color: {{tenue}}; font-size: 13px; }
.time { color: {{acento}}; font-size: 11px; margin-right: 26px; }
.close-button { background: {{acento}}; color: {{sobre}}; border: none; border-radius: 100px; min-width: 22px; min-height: 22px; margin: 8px; padding: 0; }
.close-button:hover { background: {{acento2}}; }
.control-center { background: {{fondo.rgba94}}; border: 2px solid {{acento2}}; border-radius: 18px; padding: 10px; color: {{texto}}; }
.widget-title { color: {{texto}}; font-size: 16px; font-weight: bold; margin: 8px; }
.widget-title > button { background: {{fondo2}}; color: {{texto}}; border: none; border-radius: 10px; padding: 4px 12px; }
.widget-title > button:hover { background: {{acento}}; color: {{sobre}}; }
.widget-dnd { margin: 8px; color: {{texto}}; font-size: 14px; }
.widget-dnd > switch { background: {{fondo2}}; border: none; border-radius: 12px; }
.widget-dnd > switch:checked { background: {{acento}}; }
.widget-dnd > switch slider { background: {{texto}}; border-radius: 12px; }
.widget-mpris { margin: 8px; }
.widget-mpris-player { background: {{fondo2}}; border-radius: 14px; padding: 10px; }
/* Botones de acción (ej. Abrir / Carpeta / Editar / Borrar de las capturas) */
.notification-action { background: {{fondo2}}; border-radius: 10px; margin: 4px; padding: 0; }
.notification-action > button { background: transparent; border: none; box-shadow: none; color: {{texto}}; font-weight: bold; padding: 6px 10px; }
.notification-action:hover { background: {{acento}}; }
.notification-action:hover > button { color: {{sobre}}; }
/* Vista previa de imágenes dentro de la notificación */
.notification picture { border-radius: 12px; margin-top: 8px; }
