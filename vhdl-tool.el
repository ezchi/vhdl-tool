;;; vhdl-tool.el --- Emacs package for using vhdl-tool -*- lexical-binding: t; -*-
;;
;; Copyright (C) 2020 Enze Chi
;;
;; Author: Enze Chi <http://github/ezchi>
;; Maintainer: Enze Chi <Enze.Chi@gmail.com>
;; Created: August 28, 2020
;; Modified: August 28, 2020
;; Version: 0.0.1
;; Keywords:
;; Homepage: https://github.com/ezchi/vhdl-tool
;; Package-Requires: (vhdl-mode flycheck projectile (cl-lib "0.5"))
;;
;; This file is not part of GNU Emacs.
;;
;;; Commentary:
;;
;;  Emacs package for using vhdl-tool as LSP and flycheck checker.
;;
;;; Code:

(require 'flycheck)
(require 'projectile)
(require 'lsp)

(defvar vhdl-tool-config "vhdltool-config.yaml"
  "Default config file for vhdl-tool.")

;;; config flycheck for linting
(flycheck-define-checker vhdl-tool
  "A VHDL syntax checker, type checker and linter using VHDL-Tool.
See `http://vhdltool.com'."
  :command ("vhdl-tool" "client" "lint" "--compact" source-inplace)
  :error-patterns
  ((warning line-start (file-name) ":" line ":" column ":w:" (message) line-end)
   (error line-start (file-name) ":" line ":" column ":e:" (message) line-end))
  :modes vhdl-mode)

(defun vhdl-tool--server-process-buffer-name ()
  "Get vhdl-tool server name for current project."
  (format "vhdl-tool server@%s" (projectile-project-root)))

(defun vhdl-tool--server-start-p (buffer)
  "Return non-nil if the BUFFER associated process is started."
  (let ((process (get-buffer-process buffer)))
    (if process(eq (process-status (get-buffer-process buffer)) 'run)
      nil)))

(defun vhdl-tool-server-stop ()
  "Stop vhdl-tool server if it is started."
  (interactive)
  (let ((buffer (vhdl-tool--server-process-buffer-name)))
    (when (vhdl-tool--server-start-p buffer)
      (kill-process (get-buffer-process buffer)))))

(defun vhdl-tool-server-start ()
  "Start vhdl-tool server for flycheck."
  (interactive)
  (let* ((default-directory (projectile-project-root))
         (buffer (vhdl-tool--server-process-buffer-name)))
    (unless (executable-find "vhdl-tool")
      (error "Can not find vhdl-tool"))
    (unless (file-exists-p vhdl-tool-config)
      (error "Can not find %s @ %s" vhdl-tool-config default-directory))
    (unless (vhdl-tool--server-start-p buffer)
      (message "Starting vhdl-tool server")
      (start-process "vhdl-tool-sever" buffer "vhdl-tool" "server"))))

;;; LSP

(require 'lsp-mode)
(lsp-register-client
 (make-lsp-client :new-connection (lsp-stdio-connection '("vhdl-tool" "lsp"))
                  :major-modes '(vhdl-mode)
                  :language-id "VHDL"
                  :priority -1
                  :server-id 'lsp-vhdl))

(defun vhdl-tool--whitespace-or-empty-line-p ()
  "Return non-nil if current line is empty or whitespaces only."
  (looking-at "^[[:space:]\n]*$"))

(defun vhdl-tool--skip-lsp-hover-on-empty-line (f &rest args)
  "Skip lsp-hover on empty or whitespaces only lines."
  (if (vhdl-tool--whitespace-or-empty-line-p)
      (setq lsp--hover-saved-bounds nil
            lsp--eldoc-saved-message nil)
    (apply f args)))

(defun vhdl-tool-initilize ()
  "Initialize vhdl-tool."
  (interactive)
  (lsp-deferred)
  (vhdl-tool-server-start)
  (advice-add 'lsp-hover :around #'vhdl-tool--skip-lsp-hover-on-empty-line))

(provide 'vhdl-tool)
;;; vhdl-tool.el ends here
