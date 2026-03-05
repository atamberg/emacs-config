;; -*- lexical-binding: t; -*-

;; The default is 800 kilobytes.  Measured in bytes.
(setq gc-cons-threshold (* 50 1000 1000))

;; Profile emacs startup
(add-hook 'emacs-startup-hook
          (lambda ()
            (message "*** Emacs loaded in %s seconds with %d garbage collections."
                     (emacs-init-time "%.2f")
                     gcs-done)))

;; Silence compiler warnings as they can be pretty disruptive
(setq native-comp-async-report-warnings-errors nil)

;; Set the right directory to store the native comp cache
(add-to-list 'native-comp-eln-load-path (expand-file-name "eln-cache/" user-emacs-directory))

;; Install Elpaca
(defvar elpaca-installer-version 0.11)
(defvar elpaca-directory (expand-file-name "elpaca/" user-emacs-directory))
(defvar elpaca-builds-directory (expand-file-name "builds/" elpaca-directory))
(defvar elpaca-repos-directory (expand-file-name "repos/" elpaca-directory))
(defvar elpaca-order '(elpaca :repo "https://github.com/progfolio/elpaca.git"
                              :ref nil :depth 1 :inherit ignore
                              :files (:defaults "elpaca-test.el" (:exclude "extensions"))
                              :build (:not elpaca--activate-package)))
(let* ((repo  (expand-file-name "elpaca/" elpaca-repos-directory))
       (build (expand-file-name "elpaca/" elpaca-builds-directory))
       (order (cdr elpaca-order))
       (default-directory repo))
  (add-to-list 'load-path (if (file-exists-p build) build repo))
  (unless (file-exists-p repo)
    (make-directory repo t)
    (when (<= emacs-major-version 28) (require 'subr-x))
    (condition-case-unless-debug err
        (if-let* ((buffer (pop-to-buffer-same-window "*elpaca-bootstrap*"))
                  ((zerop (apply #'call-process `("git" nil ,buffer t "clone"
                                                  ,@(when-let* ((depth (plist-get order :depth)))
                                                      (list (format "--depth=%d" depth) "--no-single-branch"))
                                                  ,(plist-get order :repo) ,repo))))
                  ((zerop (call-process "git" nil buffer t "checkout"
                                        (or (plist-get order :ref) "--"))))
                  (emacs (concat invocation-directory invocation-name))
                  ((zerop (call-process emacs nil buffer nil "-Q" "-L" "." "--batch"
                                        "--eval" "(byte-recompile-directory \".\" 0 'force)")))
                  ((require 'elpaca))
                  ((elpaca-generate-autoloads "elpaca" repo)))
            (progn (message "%s" (buffer-string)) (kill-buffer buffer))
          (error "%s" (with-current-buffer buffer (buffer-string))))
      ((error) (warn "%s" err) (delete-directory repo 'recursive))))
  (unless (require 'elpaca-autoloads nil t)
    (require 'elpaca)
    (elpaca-generate-autoloads "elpaca" repo)
    (let ((load-source-file-function nil)) (load "./elpaca-autoloads"))))
(add-hook 'after-init-hook #'elpaca-process-queues)
(elpaca `(,@elpaca-order))  ;; Install a package via the elpaca macro
;; See the "recipes" section of the manual for more details.

;; (elpaca example-package)

;; Install use-package support
(elpaca elpaca-use-package
  ;; Enable use-package :ensure support for Elpaca.
  (elpaca-use-package-mode))

(elpaca-wait)

;;When installing a package used in the init file itself,
;;e.g. a package which adds a use-package key word,
;;use the :wait recipe keyword to block until that package is installed/configured.
;;For example:
;;(use-package general :ensure (:wait t) :demand t)
;; Expands to: (elpaca evil (use-package evil :demand t))

(use-package evil 
  :ensure t
  :after undo-tree
  :init
  (setq evil-want-integration t)
  (setq evil-want-keybinding nil)
  (setq evil-want-C-u-scroll t)
  (setq evil-want-C-i-jump nil)
  (setq evil-respect-visual-line-mode t)
  (setq evil-undo-system 'undo-tree)
  (setq evil-want-minibuffer 't)
  :demand t 
  :config
  (evil-mode 1)
  ;;(define-key evil-normal-state-map (kbd "C-h") 'windmove-left)
  ;;(define-key evil-normal-state-map (kbd "C-j") 'windmove-down)
  ;;(define-key evil-normal-state-map (kbd "C-k") 'windmove-up)
  ;;(define-key evil-normal-state-map (kbd "C-l") 'windmove-right)

  (define-key evil-normal-state-map (kbd "J") 'evil-forward-paragraph)
  (define-key evil-normal-state-map (kbd "K") 'evil-backward-paragraph)
  ;; Use visual line motions even outside of visual-line-mode buffers
  (evil-global-set-key 'motion "j" 'evil-next-visual-line)
  (evil-global-set-key 'motion "k" 'evil-previous-visual-line)
  
  ;; org mode return
  (evil-define-key 'normal org-mode-map (kbd "RET") 'evil-org-return)
  )

(use-package undo-tree
  :ensure t
  :init
  (global-undo-tree-mode 1))

(use-package emacs
  :ensure nil
  :init
  (scroll-bar-mode -1)        ; Disable visible scrollbar
  (tool-bar-mode -1)          ; Disable the toolbar
  (tooltip-mode -1)           ; Disable tooltips
  (set-fringe-mode 10)       ; Give some breathing room
  (menu-bar-mode -1)            ; Disable the menu bar
  :custom
  ;; line numbers
  (column-number-mode t)
  (global-display-line-numbers-mode t)
  (display-line-numbers-type 'relative)

  ;; Scroll Stuff
  (mouse-wheel-scroll-amount '(3 ((shift) . 1))) ;; one line at a time
  (mouse-wheel-progressive-speed nil) ;; don't accelerate scrolling
  (mouse-wheel-follow-mouse t) ;; scroll window under mouse
  (scroll-step 1) ;; keyboard scroll one line at a time
  (use-dialog-box nil)

  (ring-bell-function #'ignore)
  (inhibit-startup-message t)

  ;; Set up the visible bell
  (visible-bell t)
  
  ;; recent files
  (recentf-mode t)
  :config
  (electric-pair-mode t) 
  ;; disable auto pairs for <>
  (add-hook 'org-mode-hook (lambda ()
         (setq-local electric-pair-inhibit-predicate
                 `(lambda (c)
                (if (char-equal c ?<) t (,electric-pair-inhibit-predicate c))))))
  ;; disable line numbers for some modes
  (dolist (mode '(term-mode-hook
		  shell-mode-hook
		  treemacs-mode-hook
		  neotree-mode-hook
		  eshell-mode-hook
		  ))
    (add-hook mode (lambda () (display-line-numbers-mode 0))))

  ;; Make ESC quit prompts
  (global-set-key (kbd "<escape>") 'keyboard-escape-quit)

  ;; set font && font size
  (set-face-attribute 'default nil :font "IBM Plex Mono" :height 110 )
  
  ;; set background transparency
  (add-to-list 'default-frame-alist '(alpha-background . 95))
  (defun org-export-output-file-name-modified (orig-fun extension &optional subtreep pub-dir)
    (unless pub-dir
      (setq pub-dir "exported-org-files")
      (unless (file-directory-p pub-dir)
	(make-directory pub-dir)))
    (apply orig-fun extension subtreep pub-dir nil))
  (advice-add 'org-export-output-file-name :around #'org-export-output-file-name-modified)
  )

(use-package doom-themes
  :ensure t
  :init (load-theme 'doom-gruvbox t)
  )

(use-package nerd-icons
  :ensure t
  :custom (nerd-icons-font-family "Lilex Nerd Font"))

(use-package doom-modeline
  :ensure t
  :after nerd-icons
  :init (doom-modeline-mode 1)
  :config
  (setq doom-modeline-height 15))

(use-package rainbow-delimiters
  :ensure t
  :hook (prog-mode . rainbow-delimiters-mode))

(use-package olivetti
  :ensure t
  :custom
  (olivetti-body-width 100)
  (olivetti-style 'fancy)
  :hook
  (olivetti-mode-on . (lambda () (display-line-numbers-mode 0)))
  (olivetti-mode-off . (lambda () (display-line-numbers-mode 1)))
  )

(use-package no-littering
  :ensure t
  :config
  (no-littering-theme-backups))

(use-package which-key
  :ensure t
  :init
  (setq which-key-idle-delay 0.5)
  (which-key-mode)
  :diminish whick-key-mode
  )

(use-package general
  :ensure (:wait t)
  :demand t
  :config
  (general-evil-setup t)
  (general-create-definer cfg/leader-key-func
    :keymaps '(normal insert visual emacs)
    :prefix "SPC"
    :global-prefix "C-SPC"))

(use-package projectile
  :ensure t
  :config (projectile-mode)
  :bind-keymap
  ("C-c p" . projectile-command-map)
  :init
  ;; NOTE: Set this to the folder where you keep your Git repos!
  (when (file-directory-p "~/code")
    (setq projectile-project-search-path '("~/code")))
  (setq projectile-switch-project-action #'projectile-dired)
  (setq savehist-additional-variables'(projectile-project-command-history)))

;; Enable vertico
(use-package vertico
  :ensure t
  :general
  (:states '(normal insert motion emacs) :keymaps 'vertico-map
   "<escape>" #'keyboard-escape-quit
   "C-j"      #'vertico-next
   "C-k"      #'vertico-previous
   "M-RET"    #'vertico-exit)
  :hook (after-init . vertico-mode)
  ;; :custom
  ;; (vertico-scroll-margin 0) ;; Different scroll margin
  ;; (vertico-count 20) ;; Show more candidates
  ;; (vertico-resize t) ;; Grow and shrink the Vertico minibuffer
  ;; (vertico-cycle t) ;; Enable cycling for `vertico-next/previous'
  :init
  (vertico-mode))

;; Persist history over Emacs restarts. Vertico sorts by history position.
(use-package savehist
  :ensure nil
  :init
  (savehist-mode))

;; Enable Consult
(use-package consult
  :ensure t)

(use-package marginalia
  :ensure t
  :config
  (marginalia-mode))

(use-package embark
    :ensure t

    :bind
    (("C-." . embark-act)         ;; pick some comfortable binding
     ("C-;" . embark-dwim)        ;; good alternative: M-.
     ("C-h B" . embark-bindings)) ;; alternative for `describe-bindings'

    :init

    ;; Optionally replace the key help with a completing-read interface
    (setq prefix-help-command #'embark-prefix-help-command)

    ;; Show the Embark target at point via Eldoc. You may adjust the
    ;; Eldoc strategy, if you want to see the documentation from
    ;; multiple providers. Beware that using this can be a little
    ;; jarring since the message shown in the minibuffer can be more
    ;; than one line, causing the modeline to move up and down:

    ;; (add-hook 'eldoc-documentation-functions #'embark-eldoc-first-target)
    ;; (setq eldoc-documentation-strategy #'eldoc-documentation-compose-eagerly)

    :config
    ;; Hide the mode line of the Embark live/completions buffers
    (add-to-list 'display-buffer-alist
                 '("\\`\\*Embark Collect \\(Live\\|Completions\\)\\*"
                   nil
                   (window-parameters (mode-line-format . none)))))

  ;; Consult users will also want the embark-consult package.
  (use-package embark-consult
    :ensure t ; only need to install it, embark loads it after consult if found
    :hook
    (embark-collect-mode . consult-preview-at-point-mode))

(use-package corfu
  :ensure t
  ;; TAB-and-Go customizations
  :custom
  (corfu-auto t)
  (corfu-auto-delay 0.1)
  (corfu-auto-prefix 1)
  ;; (corfu-cycle t)           ;; Enable cycling for `corfu-next/previous'
  (corfu-preselect 'directory) ;; Always preselect the prompt if its a directory

  ;; Use TAB for cycling, default is `corfu-complete'.
  :bind
  (:map corfu-map
        ("TAB" . corfu-next)
        ([tab] . corfu-next)
        ("S-TAB" . corfu-previous)
        ([backtab] . corfu-previous))

  :init
  (global-corfu-mode))
  ;; A few more useful configurations...
  (use-package emacs
    :ensure nil
    :custom
    ;; TAB cycle if there are only few candidates
    ;; (completion-cycle-threshold 3)

    ;; Enable indentation+completion using the TAB key.
    ;; `completion-at-point' is often bound to M-TAB.
    (tab-always-indent 'complete)

    ;; Emacs 30 and newer: Disable Ispell completion function.
    ;; Try `cape-dict' as an alternative.
    (text-mode-ispell-word-completion nil)

    ;; Support opening new minibuffers from inside existing minibuffers.
    (enable-recursive-minibuffers t)
    ;; Hide commands in M-x which do not work in the current mode.  Vertico
    ;; commands are hidden in normal buffers. This setting is useful beyond
    ;; Vertico.
    (read-extended-command-predicate #'command-completion-default-include-p)
    :init
    ;; Add prompt indicator to `completing-read-multiple'.
    ;; We display [CRM<separator>], e.g., [CRM,] if the separator is a comma.
    (defun crm-indicator (args)
      (cons (format "[CRM%s] %s"
  		  (replace-regexp-in-string
  		   "\\`\\[.*?]\\*\\|\\[.*?]\\*\\'" ""
  		   crm-separator)
  		  (car args))
  	  (cdr args)))
    (advice-add #'completing-read-multiple :filter-args #'crm-indicator)

    ;; Do not allow the cursor in the minibuffer prompt
    (setq minibuffer-prompt-properties
  	'(read-only t cursor-intangible t face minibuffer-prompt))
    (add-hook 'minibuffer-setup-hook #'cursor-intangible-mode))

;; Optionally use the `orderless' completion style.

(use-package orderless
  :ensure t
  :custom
  ;; Configure a custom style dispatcher (see the Consult wiki)
  ;; (orderless-style-dispatchers '(+orderless-consult-dispatch orderless-affix-dispatch))
  ;; (orderless-component-separator #'orderless-escapable-split-on-space)
  (completion-styles '(orderless basic))
  (completion-category-defaults nil)
  (completion-category-overrides '((file (styles partial-completion)))))

(use-package org
  :ensure t
  :hook (org-mode . (lambda ()
  		      (org-indent-mode)
  		      (visual-line-mode 1)
  		      (setq org-src-tab-acts-natively t)
  		      (setq org-hide-leading-stars t))
  		  )
  :config 
  (setq org-ellipsis " ▾"
	org-pretty-entities t
	org-use-sub-superscripts nil
  	org-src-tab-acts-natively t
  	org-edit-src-content-indentation 2
  	org-src-preserve-indentation nil
  	org-startup-folded 'showeverything
  	org-babel-min-lines-for-block-output 0 ;; results in an example block!
  	org-startup-with-inline-images t
  	org-link-frame-setup '((file . find-file))
  	
  	org-babel-default-header-args
  	(cons '(:results . "output verbatim replace")
              (assq-delete-all :results org-babel-default-header-args))
  	org-confirm-babel-evaluate nil
	org-return-follows-link t
	org-log-done 'time
	org-agenda-files '("~/org/agenda")
	
  	;; org-babel-results-keyword "results"
  	)	
  (add-hook 'org-mode-hook 'olivetti-mode) ;; prettier writing env
  
  (require `org-tempo) 

  (add-to-list 'org-structure-template-alist '("sh" . "src sh"))
  (add-to-list 'org-structure-template-alist '("el" . "src emacs-lisp"))
  (add-to-list 'org-structure-template-alist '("li" . "src lisp"))
  (add-to-list 'org-structure-template-alist '("sc" . "src scheme"))
  (add-to-list 'org-structure-template-alist '("ts" . "src typescript"))
  (add-to-list 'org-structure-template-alist '("py" . "src python"))
  (add-to-list 'org-structure-template-alist '("go" . "src go"))
  (add-to-list 'org-structure-template-alist '("yaml" . "src yaml"))
  (add-to-list 'org-structure-template-alist '("json" . "src json"))
  (add-to-list 'org-structure-template-alist '("cpp" . "src cpp"))
  (add-to-list 'org-structure-template-alist '("java" . "src java"))
  :init
  (org-babel-do-load-languages
   'org-babel-load-languages
   '(
     (shell . t)
     (C . t)
     (emacs-lisp . t)
     (python . t)
     (java . t)
     (cpp . t)
     )
   )
  )

(use-package evil-org
  :ensure t
  :after org
  :hook (org-mode . evil-org-mode)
  :config
  (require 'evil-org-agenda)
  (evil-org-agenda-set-keys)
  )

(use-package org-roam
  :ensure t
  :custom
  (org-roam-directory (file-truename "~/org/roam"))
  ;; (org-roam-completion-everywhere t)
  (org-roam-capture-templates
   '(("d" "default" plain
      "%?"
      :if-new (file+head "${slug}.org" "#+title: ${title}\n#+date: %U\n")
      :unnarrowed t)
     ))
  :bind (("C-c n l" . org-roam-buffer-toggle)
    	 ("C-c n f" . org-roam-node-find)
    	 ("C-c n g" . org-roam-graph)
    	 ("C-c n i" . org-roam-node-insert)
    	 ("C-c n c" . org-roam-capture)
    	 ;; Dailies
    	 ("C-c n j" . org-roam-dailies-capture-today)
	 ("C-c n I" . org-roam-node-insert-immediate)
	 )
  :config
  ;; If you're using a vertical completion framework, you might want a more informative completion interface
  (setq org-roam-node-display-template (concat "${title:*} " (propertize "${tags:10}" 'face 'org-tag)))
  (org-roam-db-autosync-mode)
  (add-to-list 'display-buffer-alist
               '("\\*org-roam\\*"
    		 (display-buffer-in-direction)
    		 (direction . right)
    		 (window-width . 0.33)
    		 (window-height . fit-window-to-buffer)))
  ;; Get `org-roam-preview-visit' and friends to replace the main window. This
  ;;should be applicable only when `org-roam-mode' buffer is displayed in a
  ;;side-window.
  (add-hook 'org-roam-mode-hook
            (lambda ()
              (setq-local display-buffer--same-window-action
                          '(display-buffer-use-some-window
                            (main)))))
  
  ;; Bind this to C-c n I
  (defun org-roam-node-insert-immediate (arg &rest args)
    (interactive "P")
    (let ((args (cons arg args))
          (org-roam-capture-templates (list (append (car org-roam-capture-templates)
                                                    '(:immediate-finish t)))))
      (apply #'org-roam-node-insert args)))
  )

(use-package org-roam-ui
  :ensure
  (:host github :repo "org-roam/org-roam-ui" :branch "main" :files ("*.el" "out"))
  :after org-roam
  ;;         normally we'd recommend hooking orui after org-roam, but since org-roam does not have
  ;;         a hookable mode anymore, you're advised to pick something yourself
  ;;         if you don't care about startup time, use
  ;;  :hook (after-init . org-roam-ui-mode)
  :config
  (setq org-roam-ui-sync-theme t
        org-roam-ui-follow t
        org-roam-ui-update-on-save t
        org-roam-ui-open-on-start t))

(use-package auctex
  :ensure t
  :config
  (setq org-format-latex-options (plist-put org-format-latex-options :scale 1))
  )

(use-package lsp-mode
  :ensure t
  :commands (lsp Lsp-deferred)
  :hook (lsp-mode . efs/lsp-mode-setup)
  :init
  (setq lsp-keymap-prefix "C-c l")  ;; Or 'C-l', 's-l'
  :config
  (lsp-enable-which-key-integration t)
	(lsp-idle-delay 0.1))

;; Automatically tangle our init.org config file when we save it
(defun cfg/org-babel-tangle-config ()
  (when (string-equal (buffer-file-name)
			(expand-file-name "./init.org"))
    ;; Dynamic scoping to the rescue
    (let ((org-confirm-babel-evaluate nil))
	(org-babel-tangle))))

(add-hook 'org-mode-hook (lambda () (add-hook 'after-save-hook #'cfg/org-babel-tangle-config)))

(cfg/leader-key-func
 ;; project
 "p" '(:wk "[P]roject")
 "pn"  'projectile-add-known-project
 "pi"  'projectile-project-info
 "pr"  'projectile-run-project
 "ps"  'projectile-switch-project
 "pp"  'projectile-find-file
 "pc"  'projectile-compile-project
 "pd"  'projectile-dired

 ;; search
 "s" '(:wk "[S]earch")
 "s."  'consult-recent-file
 "<SPC>"  'consult-buffer

 ;; org
 "o" '(:wk "[O]rg")
 "oa" 'consult-org-agenda
 "oh" 'consult-org-heading
 "of" 'org-roam-node-find
 "oc" 'org-roam-capture
 "ol" 'org-roam-buffer-toggle
 "oi" 'org-roam-node-insert
 "ot" 'org-roam-tag-add
 "oI" 'org-roam-node-insert-immediate
 )
