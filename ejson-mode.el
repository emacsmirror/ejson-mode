;;; ejson-mode.el --- Major Mode for editing ejson files. -*- lexical-binding: t -*-

;; URL: https://github.com/dantecatalfamo/ejson-mode
;; Version: 0.2.0
;; Package-Requies: ((emacs "24"))

;;; Commentary:

;; Major mode designed for editing ejson files.  Automatically encrypt
;; files on save, with 'C-c C-e' bound to manually encrypting file
;; without saving and 'C-c C-d' bound to decrypting the file into
;; the current buffer.  The variable 'ejson-keystore-location' can be
;; used to automatically specify the location of the ejson keystore,
;; and 'ejson-binary-location' can be used to manually specify the
;; location of the ejson binary.  'ejson-encrypt-on-save' can be
;; used to disable automatic encryption on save."

;;; Code:

(require 'json)


(defgroup ejson-mode nil
  "Customize variables for ejson-mode."
  :group 'js)

(defcustom ejson-binary-location nil
  "The location of the ejson binary.
If nil, binary location is determined with PATH environment variable."
  :type '(choice (const :tag "Get location from $PATH" nil)
                 (file :tag "Specify location"))
  :group 'ejson-mode)


(defcustom ejson-keystore-location nil
  "The location of the ejson keystore.
Used to set the environment variable EJSON_KEYDIR when
calling ejson.  If nil use the ejson default directory."
  :type '(choice (const :tag "Use default location" nil)
                 (directory :tag "Specify location"))
  :group 'ejson-mode)


(defcustom ejson-encrypt-on-save t
  "If non-nil, automatically encrypt ejson on save."
  :type 'boolean
  :group 'ejson-mode)


(defconst ejson-output-buffer "*ejson output*"
  "Output buffer of the ejson command.")


(defun ejson--json-read-buffer ()
  "Read the read the buffer as JSON and return it formatted as an alist."
  (save-excursion
    (goto-char (point-min))
    (json-read-object)))


(defun ejson--replace-buffer (string)
  "Helper function, replace the contents of the current buffer with STRING."
  (erase-buffer)
  (insert string))

(defun ejson-run-command (args)
  "Run the ejson command with the ARGS arguments."
  (when ejson-keystore-location
    (setenv "EJSON_KEYDIR" ejson-keystore-location))
  (if (eq 0 (shell-command (concat (or ejson-binary-location "ejson")
                                   " "
                                   args)
                           ejson-output-buffer))
      (with-current-buffer ejson-output-buffer
        (replace-regexp-in-string "\n$" "" (buffer-string)))
    (view-buffer-other-window ejson-output-buffer)))


(defun ejson-generate-key ()
  "Generate a new key for ejson, return the piblic key and store the private key in the ejson-keystore."
  (ejson-run-command "keygen -w"))


(defun ejson-encrypt-file (path)
  "Use ejson to encrypt a file at PATH."
  (ejson-run-command (concat "encrypt " path)))


(defun ejson-decrypt-file (path)
  "Use ejson to decrypt a file at PATH and return it as a string."
  (ejson-run-command (concat "decrypt " path)))


(defun ejson-get-file-key (path)
  "Get ejson key from file at PATH."
  (alist-get '_public_key (json-read-file path)))


(defun ejson-get-buffer-key ()
  "Get ejson key from current buffer."
  (alist-get '_public_key (json-read-buffer)))


(defun ejson-insert-key (ejson-key)
  "Insert EJSON-KEY into the current buffer."
  (ejson--replace-buffer
   (json-encode-alist (cons (cons '_public_key ejson-key)
                                           (json-read-buffer))))
    (json-pretty-print-buffer))


(defun ejson-encrypt-and-reload ()
  "Use ejson to encrypt file used by current buffer, then reload.
Does not automatically save the buffer before encryption."
  (interactive)
  (ejson-encrypt-file (buffer-file-name))
  (revert-buffer t t)
  (message "%s Encrypted" (buffer-name)))


(defun ejson-prompt-generate-key ()
  "Check if the current buffer has a public key, and prompt the user to generate one if it doesn't."
  (interactive)
  (unless (ejson-get-buffer-key)
    (if (y-or-n-p (concat (buffer-name) " has no encryption key, generate one?"))
        (ejson-insert-key (ejson-generate-key))
      (message "Cannot encrypt %s without a key" (buffer-name)))))


(defun ejson-decrypt-in-buffer ()
  "Decrypt the contents of the open ejson file, replacing the buffer's contents."
  (interactive)
  (ejson--replace-buffer (ejson-decrypt-file (buffer-file-name)))
  (message "%s Decrypted" (buffer-name)))


(defun ejson-generate-on-save()
  "Run on ejson save, choose whether to prompt for key generation or not."
  (when ejson-encrypt-on-save
    (ejson-prompt-generate-key)))

(defun ejson-encrypt-on-save ()
  "Run on ejson save, chooses whether to automatically encrypt or not."
  (when ejson-encrypt-on-save
    (ejson-encrypt-and-reload)))

(defvar ejson-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-d") 'ejson-decrypt-in-buffer)
    (define-key map (kbd "C-c C-e") 'ejson-encrypt-and-reload)
    map))

;;;###autoload
(define-derived-mode ejson-mode js-mode "Encrypted-JSON"
  "Major mode for editing ejson files"
  (add-hook 'before-save-hook 'ejson-generate-on-save nil t)
  (add-hook 'after-save-hook 'ejson-encrypt-on-save nil t))


;;;###autoload
(add-to-list 'auto-mode-alist '("\\.ejson\\'" . ejson-mode))

(provide 'ejson-mode)
;;; ejson-mode.el ends here
