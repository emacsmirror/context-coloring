;;; context-coloring.el --- Syntax highlighting, except not for syntax. -*- lexical-binding: t; -*-

;; Copyright (C) 2014 Jackson Ray Hamilton

;; Author: Jackson Ray Hamilton <jackson@jacksonrayhamilton.com>
;; Keywords: context coloring syntax highlighting
;; Version: 1.0.0
;; Package-Requires: ((emacs "24"))

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Colors code by scope, rather than by syntax.

;; A range of characters encompassing a scope is colored according to its level;
;; the global scope is white, scopes within the global scope are yellow, scopes
;; within scopes within the global scope are green, etc.  Variables defined in a
;; parent scope which are referenced from child scopes retain the same color as
;; the scope in which they are defined; a variable defined in the global scope
;; will be the same color when referenced from nested scopes.

;; To use, add the following to your ~/.emacs:

;; (require 'context-coloring)
;; (add-hook 'js-mode-hook 'context-coloring-mode) ; Requires Node.js 0.10+.

;;; Code:

;;; Faces

(defface context-coloring-level--1-face
  '((((type tty)) (:foreground "white"))
    (t (:foreground "#7f7f7f")))
  "Context coloring face, level -1; comments."
  :group 'context-coloring-faces)

(defface context-coloring-level-0-face
  '((((type tty)) (:foreground "white"))
    (((background light)) (:foreground "#000000"))
    (((background dark)) (:foreground "#ffffff")))
  "Context coloring face, level 0; global scope."
  :group 'context-coloring-faces)

(defface context-coloring-level-1-face
  '((((type tty)) (:foreground "yellow"))
    (((background light)) (:foreground "#007f80"))
    (((background dark)) (:foreground "#ffff80")))
  "Context coloring face, level 1."
  :group 'context-coloring-faces)

(defface context-coloring-level-2-face
  '((((type tty)) (:foreground "green"))
    (((background light)) (:foreground "#001580"))
    (((background dark)) (:foreground "#cdfacd")))
  "Context coloring face, level 2."
  :group 'context-coloring-faces)

(defface context-coloring-level-3-face
  '((((type tty)) (:foreground "cyan"))
    (((background light)) (:foreground "#550080"))
    (((background dark)) (:foreground "#d8d8ff")))
  "Context coloring face, level 3."
  :group 'context-coloring-faces)

(defface context-coloring-level-4-face
  '((((type tty)) (:foreground "blue"))
    (((background light)) (:foreground "#802b00"))
    (((background dark)) (:foreground "#e7c7ff")))
  "Context coloring face, level 4."
  :group 'context-coloring-faces)

(defface context-coloring-level-5-face
  '((((type tty)) (:foreground "magenta"))
    (((background light)) (:foreground "#6a8000"))
    (((background dark)) (:foreground "#ffcdcd")))
  "Context coloring face, level 5."
  :group 'context-coloring-faces)

(defface context-coloring-level-6-face
  '((((type tty)) (:foreground "red"))
    (((background light)) (:foreground "#008000"))
    (((background dark)) (:foreground "#ffe390")))
  "Context coloring face, level 6."
  :group 'context-coloring-faces)

;;; Additional 6 faces as placeholders for potential (insane) levels of nesting.

(defface context-coloring-level-7-face
  '((t (:inherit context-coloring-level-1-face)))
  "Context coloring face, level 7."
  :group 'context-coloring-faces)

(defface context-coloring-level-8-face
  '((t (:inherit context-coloring-level-2-face)))
  "Context coloring face, level 8."
  :group 'context-coloring-faces)

(defface context-coloring-level-9-face
  '((t (:inherit context-coloring-level-3-face)))
  "Context coloring face, level 9."
  :group 'context-coloring-faces)

(defface context-coloring-level-10-face
  '((t (:inherit context-coloring-level-4-face)))
  "Context coloring face, level 10."
  :group 'context-coloring-faces)

(defface context-coloring-level-11-face
  '((t (:inherit context-coloring-level-5-face)))
  "Context coloring face, level 11."
  :group 'context-coloring-faces)

(defface context-coloring-level-12-face
  '((t (:inherit context-coloring-level-6-face)))
  "Context coloring face, level 12."
  :group 'context-coloring-faces)

(defcustom context-coloring-face-count 7
  "Number of faces defined for highlighting delimiter levels.
Determines level at which to cycle through faces again.")


;;; Face functions

(defsubst context-coloring-level-face (level)
  "Return face-name for LEVEL as a string \"context-coloring-level-LEVEL-face\".
For example: \"context-coloring-level-1-face\"."
  (intern-soft
   (concat "context-coloring-level-"
           (number-to-string
            (or
             ;; Has a face directly mapping to it.
             (and (< level context-coloring-face-count)
                  level)
             ;; After the number of available faces are used up, pretend the 0th
             ;; face doesn't exist.
             (+ 1
                (mod (- level 1)
                     (- context-coloring-face-count 1)))))
           "-face")))


;;; Constants

(defconst context-coloring-path
  (file-name-directory (or load-file-name buffer-file-name))
  "This file's directory.")


;;; Local variables

(defvar-local context-coloring-buffer nil
  "Reference to this buffer (for timers).")

(defvar-local context-coloring-scopifier-process nil
  "Only allow a single scopifier process to run at a time. This
is a reference to that one process.")

(defvar-local context-coloring-colorize-idle-timer nil
  "Reference to currently-running idle timer.")

(defvar-local context-coloring-changed nil
  "Indication that the buffer has changed recently, which would
imply that it should be colorized again.")


;;; js2-mode Scopification

;; Potentially useful functions: js2-visit-ast js2-node-get-enclosing-scope
;; js2-get-defining-scope js2-visit-ast-root

(defun context-coloring-js2-mode-scopifier ()
  (vector))


;;; Scopification

(let ((javascript-scopifier `(:type shell-command
                              :executable "node"
                              :command ,(expand-file-name
                                         "./languages/javascript/bin/scopifier"
                                         context-coloring-path)))
      (js2-mode-scopifier `(:type elisp
                            :scopifier context-coloring-js2-mode-scopifier)))
  (defcustom context-coloring-scopifier-plist
    `(js-mode ,javascript-scopifier
      js2-mode ,js2-mode-scopifier
      js3-mode ,javascript-scopifier)
    "Property list mapping major modes to scopification programs."))

(defun context-coloring-apply-tokens (tokens)
  "Processes TOKENS to apply context-based coloring to the
current buffer. Tokens are 3 integers: start, end, level. The
array is flat, with a new token occurring after every 3rd
number."
  (with-silent-modifications
    ;; Reset in case there should be uncolored areas.
    (remove-text-properties (point-min) (point-max) `(face nil rear-nonsticky nil))
    (let ((i 0)
          (len (length tokens)))
      (while (< i len)
        (add-text-properties
         (elt tokens i)
         (elt tokens (+ i 1))
         `(face ,(context-coloring-level-face (elt tokens (+ i 2))) rear-nonsticky t))
        (setq i (+ i 3))))))

(defsubst context-coloring-kill-scopifier ()
  "Kills the currently-running scopifier process for this
buffer."
  (when (not (null context-coloring-scopifier-process))
    (delete-process context-coloring-scopifier-process)
    (setq context-coloring-scopifier-process nil)))

(defun context-coloring-parse-array (input)
  "Specialized JSON parser for a flat array of numbers."
  (vconcat (mapcar 'string-to-number (split-string (substring input 1 -1) ","))))

(defun context-coloring-scopify-shell-command (command)
  "Invokes a scopifier with the current buffer's contents,
reading the scopifier's response asynchronously and applying a
parsed list of tokens to `context-coloring-apply-tokens'."

  ;; Prior running tokenization is implicitly obsolete if this function is
  ;; called.
  (context-coloring-kill-scopifier)

  ;; Start the process.
  (setq context-coloring-scopifier-process
        (start-process-shell-command "scopifier" nil command))

  (let ((output "")
        (buffer context-coloring-buffer))

    ;; The process may produce output in multiple chunks. This filter
    ;; accumulates the chunks into a message.
    (set-process-filter
     context-coloring-scopifier-process
     (lambda (process chunk)
       (setq output (concat output chunk))))

    ;; When the process's message is complete, this sentinel parses it as JSON
    ;; and applies the tokens to the buffer.
    (set-process-sentinel
     context-coloring-scopifier-process
     (lambda (process event)
       (when (equal "finished\n" event)
         (let ((tokens (context-coloring-parse-array output)))
           (with-current-buffer buffer
             (context-coloring-apply-tokens tokens))
           (setq context-coloring-scopifier-process nil))))))

  ;; Give the process its input so it can begin.
  (process-send-region context-coloring-scopifier-process (point-min) (point-max))
  (process-send-eof context-coloring-scopifier-process))

(defun context-coloring-scopify ()
  "Determines the optimal track for scopification of the current
buffer, then scopifies the current buffer."
  (let ((scopifier (plist-get context-coloring-scopifier-plist major-mode)))
    (cond
     ((null scopifier)
      (message "%s" "Context coloring is not available for this major mode"))
     (t
      (let ((type (plist-get scopifier :type)))
        (cond
         ((eq type 'elisp)
          (context-coloring-apply-tokens (funcall (plist-get scopifier :scopifier))))
         ((eq type 'shell-command)
          (let ((executable (plist-get scopifier :executable)))
            (if (null (executable-find executable))
                (message "Context coloring executable \"%s\" not found" executable)
              (context-coloring-scopify-shell-command (plist-get scopifier :command)))))))))))


;;; Colorization

(defcustom context-coloring-delay 0.25
  "Delay between a buffer update and colorization.

Increase this if your machine is high-performing. Decrease it if it ain't."
  :group 'context-coloring)

(defun context-coloring-colorize ()
  "Colors the current buffer by function context."
  (interactive)
  (context-coloring-scopify))

(defun context-coloring-change-function (start end length)
  "Registers a change so that a context-colored buffer can be
colorized soon."
  ;; Tokenization is obsolete if there was a change.
  (context-coloring-kill-scopifier)
  (setq context-coloring-changed t))

(defun context-coloring-maybe-colorize ()
  "Colorize unders certain conditions. This will run as an idle
timer, so firstly the buffer must not be some other
buffer. Additionally, the buffer must have changed, otherwise
colorizing would be redundant."
  (when (and (eq context-coloring-buffer (window-buffer (selected-window)))
             context-coloring-changed)
    (setq context-coloring-changed nil)
    (context-coloring-colorize)))


;;; Minor mode

;;;###autoload
(define-minor-mode context-coloring-mode
  "Context-based code coloring, inspired by Douglas Crockford."
  nil " Context" nil
  (if (not context-coloring-mode)
      (progn
        (context-coloring-kill-scopifier)
        (when (not (null 'context-coloring-colorize-idle-timer))
          (cancel-timer context-coloring-colorize-idle-timer))
        (remove-hook 'after-change-functions 'context-coloring-change-function t)
        (font-lock-mode)
        (jit-lock-mode t))

    ;; Remember this buffer. This value should not be dynamically-bound.
    (setq context-coloring-buffer (current-buffer))

    ;; Colorize once initially.
    (context-coloring-colorize)

    ;; Font lock is incompatible with this mode; the converse is also true.
    (font-lock-mode 0)
    (jit-lock-mode nil)

    ;; Only recolor on change.
    (add-hook 'after-change-functions 'context-coloring-change-function nil t)

    ;; Only recolor idly.
    (setq context-coloring-colorize-idle-timer
          (run-with-idle-timer context-coloring-delay t 'context-coloring-maybe-colorize))))

(provide 'context-coloring)

;;; context-coloring.el ends here
